import ../lib/svn/libsvn
import posix
import request

var do_exit = false

proc timer_create*(a1: ClockId, a2: ptr SigEvent = nil, a3: var Timer): cint
   {.importc, header: "<time.h>".}

proc sigalrm_handler(x: cint) {.noconv.} =
   discard

proc sigint_handler(x: cint) {.noconv.} =
   do_exit = true


var timer: Timer
var empty_sigset: Sigset
discard sigemptyset(empty_sigset)
var alrm_action = Sigaction(sa_handler: sigalrm_handler, sa_mask: empty_sigset,
                            sa_flags: 0)
var int_action = Sigaction(sa_handler: sigint_handler, sa_mask: empty_sigset,
                           sa_flags: 0)


discard sigaction(SIGALRM, alrm_action, nil)
discard sigaction(SIGINT, int_action, nil)

discard timer_create(CLOCK_REALTIME, nil, timer)

var new_time, old_time: Itimerspec
new_time.it_value = Timespec(tv_sec: Time(2), tv_nsec: 0)
new_time.it_interval = Timespec(tv_sec: Time(10), tv_nsec: 0)
discard timer_settime(timer, 0, new_time, old_time)

type
   RepositoryTracker = object
      repository: Repository
      svn_object: SvnObject

echo "Initializing"
var trackers: seq[RepositoryTracker]
for r in get_repositories():
   echo "Initializing an SVN session\n",
        "  URL:    ", r.url, "\n",
        "  Branch: ", r.branch
   var tracker: RepositoryTracker
   tracker.svn_object = new SvnObject
   tracker.repository = r
   libsvn.init(tracker.svn_object)
   libsvn.open_session(tracker.svn_object, r.url)
   add(trackers, tracker)

while not do_exit:
   for tracker in trackers:
      # Check delta between tracker
      let so = tracker.svn_object
      let alasso_latest = get_latest_revision(tracker.repository.id)
      let server_latest = so.get_latest_log(
         [tracker.repository.branch]).revision

      if (server_latest > alasso_latest):
         const BLOCK_SIZE = 30
         # Issue updates in steps of the block size.
         var first = alasso_latest + 1
         var last = min(first + BLOCK_SIZE, server_latest)
         while (first <= last):
            echo "Attempt to find between ", first, " and ", last
            let revisions_to_post = so.get_log(first, last,
                                               [tracker.repository.branch])
            echo "Found ", len(revisions_to_post), " revisions"
            for r in revisions_to_post:
               post_revision(Revision(repository: tracker.repository.id,
                                      revision: "r" & $r.revision,
                                      description: r.message,
                                      timestamp: r.timestamp))
            first = last + 1
            last = min(first + BLOCK_SIZE, server_latest)

   discard sigsuspend(empty_sigset)

for t in mitems(trackers):
   destroy(t.svn_object)
