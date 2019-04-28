import strutils

import ./alasso
import ./utils/log
import ../lib/svn/libsvn


type
   TrackerError* = object of Exception
   RepositoryTracker* = object
      repository*: Repository
      svn_object*: SvnObject
      is_open: bool

const UPDATE_BATCH_SIZE = 30


proc new_tracker_error(msg: string, args: varargs[string, `$`]):
      ref TrackerError =
   new result
   result.msg = format(msg, args)


proc init*(t: var RepositoryTracker) =
   t.svn_object = new SvnObject
   libsvn.init(t.svn_object)


proc destroy*(t: var RepositoryTracker) =
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


proc update*(t: RepositoryTracker, alasso_url: string) =
   if not t.is_open:
      raise new_tracker_error("Tracker is not active.")

   var db_latest: int
   var server_latest: SvnRevnum
   try:
      db_latest = get_latest_revision(t.repository.id, alasso_url)
   except AlassoError as e:
      log.abort(TrackerError, "Failed to get latest revision from Alasso " &
                "database at '$1' ($2).", alasso_url, e.msg)
   try:
      server_latest =
         get_latest_log(t.svn_object, [t.repository.branch]).revision
   except SvnError as e:
      log.abort(TrackerError, "Failed to get latest log entry from SVN " &
                "server at '$1'. ($2)", t.repository.url, e.msg)

   if server_latest > db_latest:
      # Issue updates in batches of UPDATE_BATCH_SIZE.
      var first = db_latest + 1
      var last = min(first + UPDATE_BATCH_SIZE, server_latest)
      while (first <= last):
         let revisions_to_post = get_log(t.svn_object, first, last,
                                         [t.repository.branch])
         for r in revisions_to_post:
            try:
               post_revision(Revision(repository: t.repository.id,
                                      revision: "r" & $r.revision,
                                      description: r.message,
                                      timestamp: r.timestamp), alasso_url)
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
         last = min(first + UPDATE_BATCH_SIZE, server_latest)


proc update*(trackers: openarray[RepositoryTracker], alasso_url: string) =
   for t in trackers:
      update(t, alasso_url)


proc create*(trackers: var seq[RepositoryTracker], alasso_url: string) =
   ## Create trackers from repostories present in the Alasso database, add any
   ## untracked repositories to ``trackers``.
   var repositories: seq[Repository]
   try:
      repositories = alasso.get_repositories(alasso_url)
   except AlassoError as e:
      log.abort(TrackerError, "Failed to get repositories from Alasso " &
                "database at '$1'. ($2)", alasso_url, e.msg)

   for r in repositories:
      var already_tracked = false
      for t in trackers:
         # Check that a tracker does not yet exist.
         if t.repository == r:
            already_tracked = true
            break
      if already_tracked:
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
         log.abort(TrackerError, "Cannot establish a connection to the SVN " &
                   "server at '$1'. ($2)", r.url, e.msg)
