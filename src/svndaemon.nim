import ../lib/svn/libsvn
import posix
import tracker

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
new_time.it_value = Timespec(tv_sec: Time(10), tv_nsec: 0)
new_time.it_interval = Timespec(tv_sec: Time(10), tv_nsec: 0)
discard timer_settime(timer, 0, new_time, old_time)

echo "Initializing..."
var trackers: seq[RepositoryTracker]
while not do_exit:
   create(trackers)
   update(trackers)
   discard sigsuspend(empty_sigset)

echo "Destroying trackers..."
destroy(trackers)
