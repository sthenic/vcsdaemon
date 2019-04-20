import strutils

import ../lib/svn/libsvn
import request


type
   TrackerError = object of Exception
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


proc update*(t: RepositoryTracker) =
   if not t.is_open:
      raise new_tracker_error("Tracker is not active.")

   var db_latest: int
   var server_latest: SvnRevnum
   try:
      db_latest = get_latest_revision(t.repository.id)
   except RequestError:
      # TODO: Write a log message.
      echo "Failed!"
      return

   try:
      server_latest = get_latest_log(t.svn_object,
                                     [t.repository.branch]).revision
   except SvnError:
      # TODO: Write a log message.
      echo "Failed!"
      return

   if server_latest > db_latest:
      # Issue updates in batches of UPDATE_BATCH_SIZE.
      var first = db_latest + 1
      var last = min(first + UPDATE_BATCH_SIZE, server_latest)
      while (first <= last):
         let revisions_to_post = get_log(t.svn_object, first, last,
                                         [t.repository.branch])
         for r in revisions_to_post:
            post_revision(Revision(repository: t.repository.id,
                                   revision: "r" & $r.revision,
                                   description: r.message,
                                   timestamp: r.timestamp))
         first = last + 1
         last = min(first + UPDATE_BATCH_SIZE, server_latest)


proc update*(trackers: openarray[RepositoryTracker]) =
   for t in trackers:
      update(t)
