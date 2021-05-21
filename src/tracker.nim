import strutils

import ./alasso
import ./utils/log
import ../lib/svn/libsvn


type
   TrackerError* = object of ValueError
   TrackerTimeoutError* = object of TrackerError
   TrackerFatalError* = object of TrackerError
      id*: int
   RepositoryTracker* = object
      repository*: Repository
      svn_object*: SvnObject
      is_open: bool

const UPDATE_BATCH_SIZE = 30


proc abort(t: typedesc[TrackerFatalError], id: int, msg: string,
           args: varargs[string, `$`]) =
   log.error(msg, args)
   var tracker_error = new_exception(TrackerFatalError, format(msg, args))
   tracker_error.id = id
   raise tracker_error


proc init*(t: var RepositoryTracker) =
   t.svn_object = new SvnObject
   libsvn.init(t.svn_object)


proc destroy*(t: var RepositoryTracker) =
   if t.repository.id > 0:
      log.info("Removing tracker for repository:\n" &
               "URL:    " & t.repository.url & "\n" &
               "Branch: " & t.repository.branch)
   if not is_nil(t.svn_object):
      destroy(t.svn_object)


proc destroy*(trackers: var openarray[RepositoryTracker]) =
   for t in mitems(trackers):
      if not is_nil(t.svn_object):
         destroy(t.svn_object)


proc open*(t: var RepositoryTracker, r: Repository) =
   libsvn.open_session(t.svn_object, r.url)
   t.repository = r
   t.is_open = true


proc info(revisions: openarray[SvnLogObject], first, last: int): string =
   ## Helper function to generate part of the trace message following a post
   ## of one or more revisions.
   if len(revisions) == 1:
      result = "revision r" & $revisions[0].revision
   elif len(revisions) > 1:
      result = $len(revisions) & " revisions in range r" &
               $first & " - r" & $last


proc update*(t: RepositoryTracker, id: int, alasso_url: string) =
   if not t.is_open:
      log.abort(TrackerError, "Tracker is not active.")

   var db_latest_revnum, db_latest_id: int
   var server_latest_revnum: SvnRevnum
   try:
      (db_latest_revnum, db_latest_id) = get_latest_commit(t.repository.id, alasso_url)
   except AlassoTimeoutError:
      log.abort(TrackerTimeoutError, "Failed to get latest revision from " &
                "Alasso database at '$1'. Operation timed out.", alasso_url)
   except AlassoError as e:
      log.abort(TrackerError, "Failed to get latest revision from Alasso " &
                "database at '$1' ($2).", alasso_url, e.msg)
   try:
      server_latest_revnum =
         get_latest_log(t.svn_object, [t.repository.branch]).revision
   except SvnError as e:
      abort(TrackerFatalError, id, "Failed to get latest log entry from SVN " &
            "server at '$1'. ($2)", t.repository.url, e.msg)

   if server_latest_revnum > db_latest_revnum:
      # Issue updates in batches of UPDATE_BATCH_SIZE.
      var first = db_latest_revnum + 1
      var last = min(first + UPDATE_BATCH_SIZE, server_latest_revnum)
      var parent = db_latest_id
      while (first <= last):
         let revisions_to_post = get_log(t.svn_object, first, last,
                                         [t.repository.branch])
         for r in revisions_to_post:
            try:
               parent = post_commit(
                  Commit(repository: t.repository.id,
                         uid: "r" & $r.revision,
                         message: r.message,
                         author: r.author,
                         parent: parent,
                         timestamp: r.timestamp,
                         author_timestamp: r.timestamp),
                  alasso_url
               )
            except AlassoTimeoutError:
               log.abort(TrackerTimeoutError, "Failed to post revision to " &
                         "Alasso database at '$1'. Operation timed out.",
                         alasso_url)
            except AlassoError as e:
               log.abort(TrackerError, "Failed to post revision to Alasso " &
                         "database at '$1'. ($2)", alasso_url, e.msg)
         # Output a trace log message after successfully posting a batch of
         # revisions.
         if len(revisions_to_post) > 0:
            log.info("Posted $1 from $2/$3 to repository $4.",
                     info(revisions_to_post, first, last), t.repository.url,
                     t.repository.branch, t.repository.id)
         first = last + 1
         last = min(first + UPDATE_BATCH_SIZE, server_latest_revnum)


proc update*(trackers: openarray[RepositoryTracker], alasso_url: string) =
   for i, t in trackers:
      update(t, i, alasso_url)


proc create*(trackers: var seq[RepositoryTracker], alasso_url: string) =
   ## Create trackers from repostories present in the Alasso database, add any
   ## untracked repositories to ``trackers``.
   var repositories: seq[Repository]
   try:
      repositories = alasso.get_repositories(alasso_url)
   except AlassoTimeoutError:
      log.abort(TrackerTimeoutError, "Failed to get repositories from Alasso " &
                "database at '$1'. Operation timed out.", alasso_url)
   except AlassoError as e:
      log.abort(TrackerError, "Failed to get repositories from Alasso " &
                "database at '$1'. ($2)", alasso_url, e.msg)

   for r in repositories:
      var already_tracked = false
      var remove_tracker_index = -1
      # Check that a tracker does not yet exist. If it does check the archive
      # status to decide if the tracker should be removed.
      for i, t in trackers:
         if t.repository == r:
            if r.is_archived:
               remove_tracker_index = i
            already_tracked = true
            break

      if remove_tracker_index > 0:
         destroy(trackers[remove_tracker_index])
         del(trackers, remove_tracker_index)
         continue

      if r.is_archived or already_tracked:
         continue

      var t: RepositoryTracker
      init(t)
      try:
         open(t, r)
         add(trackers, t)
         log.info("Adding tracker for repository:\n" &
                  "URL:    " & r.url & "\n" &
                  "Branch: " & r.branch)
      except SvnError as e:
         destroy(t)
         log.warning("Cannot establish a connection to the SVN " &
                     "server at '$1', skipping. ($2)", r.url, e.msg)
