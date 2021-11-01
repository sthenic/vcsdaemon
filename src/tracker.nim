import strutils
import uri
import os
import md5

import ./alasso
import ./utils/log
import ../lib/svn/libsvn
import ../lib/git/libgit


type
   TrackerError* = object of ValueError
   TrackerTimeoutError* = object of TrackerError
   TrackerFatalError* = object of TrackerError
      id*: int

   TrackerKind* {.pure.} = enum
      Svn, Git

   Tracker* = object
      repository: Repository
      is_open: bool
      alasso_url: string
      case kind: TrackerKind
      of TrackerKind.Svn:
         svn_object: SvnObject
      of TrackerKind.Git:
         git_object: GitObject


const UPDATE_BATCH_SIZE = 30


proc abort(t: typedesc[TrackerFatalError], id: int, msg: string, args: varargs[string, `$`]) =
   log.error(msg, args)
   var tracker_error = new_exception(TrackerFatalError, format(msg, args))
   tracker_error.id = id
   raise tracker_error


proc destroy*(t: var Tracker) =
   case t.kind
   of TrackerKind.Svn:
      if not is_nil(t.svn_object):
         destroy(t.svn_object)
   of TrackerKind.Git:
      if not is_nil(t.git_object):
         destroy(t.git_object)

   if t.repository.id > 0:
      log.info("Removed tracker for repository:\n" &
               "URL: " & t.repository.url & "\n" &
               "Branch: " & t.repository.branch)


proc destroy*(trackers: var openarray[Tracker]) =
   for t in mitems(trackers):
      destroy(t)


proc git_repository_path_from_url(url, repository_store: string): string =
   let uri = parse_uri(url)
   var (_, path) = split_path(uri.path)
   remove_suffix(path, ".git")
   result = repository_store & "/" & path & "-" & $to_md5(url)


proc open(t: var Tracker, r: Repository, alasso_url, repository_store, ssh_public_key,
          ssh_private_key, ssh_passphrase: string) =
   case r.vcs
   of "subversion":
      t = Tracker(kind: TrackerKind.Svn)
      t.svn_object = new SvnObject
      libsvn.init(t.svn_object)
      libsvn.open_session(t.svn_object, r.url)
      log.info("Created tracker for SVN repository:\n" &
               "URL: $1\n" &
               "Branch: $2", r.url, r.branch)
   of "git":
      let path = git_repository_path_from_url(r.url, repository_store)
      t = Tracker(kind: TrackerKind.Git)
      t.git_object = new GitObject
      libgit.init(t.git_object)
      libgit.open(t.git_object, r.url, path, ssh_public_key, ssh_private_key, ssh_passphrase)
      log.info("Created tracker for Git repository:\n" &
               "URL: $1\n" &
               "Branch: $2\n" &
               "Local path: $3", r.url, r.branch, path)
   else:
      log.abort(TrackerError, "Cannot create tracker for unsupported VCS type '$1'.", r.vcs)

   t.repository = r
   t.alasso_url = alasso_url
   t.is_open = true


proc info(revisions: openarray[SvnLogObject], first, last: int): string =
   ## Helper function to generate part of the trace message following a post
   ## of one or more SVN commits.
   if len(revisions) == 1:
      result = "revision r" & $revisions[0].revision
   elif len(revisions) > 1:
      result = $len(revisions) & " revisions in range r" & $first & " - r" & $last


proc to_alasso_commit(commit: SvnLogObject, repository, parent: int): Commit =
   result = Commit(repository: repository,
                   uid: "r" & $commit.revision,
                   message: commit.message,
                   author: commit.author,
                   parent: parent,
                   timestamp: commit.timestamp,
                   author_timestamp: commit.timestamp)


proc to_alasso_commit(commit: GitLogObject, repository, parent: int): Commit =
   result = Commit(repository: repository,
                   uid: commit.hash,
                   message: commit.message,
                   author: commit.email,
                   parent: parent,
                   timestamp: commit.timestamp,
                   author_timestamp: commit.timestamp)


proc post_commit[T: SvnLogObject | GitLogObject](commit: T, repository, parent: int, alasso_url: string): int =
   try:
      result = post_commit(to_alasso_commit(commit, repository, parent), alasso_url)
   except AlassoTimeoutError:
      log.abort(TrackerTimeoutError,
                "Failed to post revision to Alasso database at '$1'. Operation timed out.",
                alasso_url)
   except AlassoError as e:
      log.abort(TrackerError, "Failed to post revision to Alasso database at '$1'. ($2)",
                alasso_url, e.msg)


proc update_svn(t: Tracker, id: int, latest_uid: string, latest_id: int) =
   var server_latest_revnum: SvnRevnum
   try:
      server_latest_revnum = get_latest_log(t.svn_object, [t.repository.branch]).revision
   except SvnError as e:
      abort(TrackerFatalError, id, "Failed to get latest log entry from SVN server at '$1'. ($2)",
            t.repository.url, e.msg)

   # TODO: Will this parse always be safe?
   let alasso_latest_revnum = if len(latest_uid) == 0: 0 else: parse_int(latest_uid[1..^1])
   if server_latest_revnum > alasso_latest_revnum:
      # Issue updates in batches of UPDATE_BATCH_SIZE.
      var first = alasso_latest_revnum + 1
      var last = min(first + UPDATE_BATCH_SIZE, server_latest_revnum)
      var parent = latest_id
      while (first <= last):
         let commits_to_post = get_log(t.svn_object, first, last, [t.repository.branch])
         for commit in commits_to_post:
            parent = post_commit(commit, t.repository.id, parent, t.alasso_url)

         # Output a trace log message after successfully posting a batch of
         # revisions.
         if len(commits_to_post) > 0:
            log.info("Posted $1 from $2/$3 to repository $4.",
                     info(commits_to_post, first, last), t.repository.url,
                     t.repository.branch, t.repository.id)
         first = last + 1
         last = min(first + UPDATE_BATCH_SIZE, server_latest_revnum)


proc update_git(t: Tracker, latest_uid: string, latest_id: int) =
   # We begin by fetching from the remote. Next, we walk the commits in one of
   # two ways, either
   #   1. the Alasso repository does not contain a commit object, so we walk and
   #      POST every commit for the target branch; or
   #   2. the Alasso repository gives us the latest commit on record, and we
   #      walk and POST any new commits between that and origin/branch.
   try:
      fetch(t.git_object, "origin")
   except GitError as e:
      log.abort(TrackerError, "Failed to fetch the Git repository at '$1/$2'. ($3)",
                t.repository.url, t.repository.branch, e.msg)

   var commits_posted = 0
   try:
      var parent = latest_id
      if len(latest_uid) == 0:
         for commit in walk_commits(t.git_object, "origin", t.repository.branch):
            parent = post_commit(commit, t.repository.id, parent, t.alasso_url)
            inc(commits_posted)
      else:
         for commit in walk_commits_range(t.git_object, latest_uid, "origin/" & t.repository.branch):
            parent = post_commit(commit, t.repository.id, parent, t.alasso_url)
            inc(commits_posted)

   except GitError as e:
      log.abort(TrackerError, "Failed to walk new commits for the Git repository at '$1/$2'. ($3)",
                t.repository.url, t.repository.branch, e.msg)

   if commits_posted > 0:
      log.info("Posted $1 commits from $2/$3 to repository $4.", commits_posted, t.repository.url,
               t.repository.branch, t.repository.id)


proc update*(t: Tracker, id: int) =
   if not t.is_open:
      log.abort(TrackerError, "Tracker is not active.")

   var latest_uid: string
   var latest_id: int
   try:
      (latest_uid, latest_id) = get_latest_commit(t.repository.id, t.alasso_url)
   except AlassoTimeoutError:
      log.abort(TrackerTimeoutError,
                "Failed to get latest revision from Alasso database at '$1'. Operation timed out.",
                t.alasso_url)
   except AlassoError as e:
      log.abort(TrackerError, "Failed to get latest revision from Alasso database at '$1' ($2).",
                t.alasso_url, e.msg)

   case t.kind
   of TrackerKind.Svn:
      update_svn(t, id, latest_uid, latest_id)
   of TrackerKind.Git:
      update_git(t, latest_uid, latest_id)


proc update*(trackers: openarray[Tracker]) =
   for i, t in trackers:
      update(t, i)


proc create*(trackers: var seq[Tracker], alasso_url, repository_store, ssh_public_key,
             ssh_private_key, ssh_passphrase: string) =
   ## Create trackers from repostories present in the Alasso database, add any
   ## untracked repositories to ``trackers``.
   var repositories: seq[Repository]
   try:
      repositories = alasso.get_repositories(alasso_url)
   except AlassoTimeoutError:
      log.abort(TrackerTimeoutError,
                "Failed to get repositories from Alasso database at '$1'. Operation timed out.",
                alasso_url)
   except AlassoError as e:
      log.abort(TrackerError, "Failed to get repositories from Alasso database at '$1'. ($2)",
                alasso_url, e.msg)

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

      if remove_tracker_index >= 0:
         destroy(trackers[remove_tracker_index])
         del(trackers, remove_tracker_index)
         continue

      if r.is_archived or already_tracked:
         continue

      var t: Tracker
      try:
         open(t, r, alasso_url, repository_store, ssh_public_key, ssh_private_key, ssh_passphrase)
         add(trackers, t)
      except SvnError as e:
         destroy(t)
         log.warning("Cannot establish a connection to the SVN server at '$1', skipping. ($2)",
                     r.url, e.msg)
      except GitError as e:
         destroy(t)
         log.warning("Cannot establish a connection to the Git remote at '$1', skipping. ($2)",
                     r.url, e.msg)
