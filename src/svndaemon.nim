import ../lib/svn/libsvn
import posix

var do_exit = false

proc timer_create*(a1: ClockId, a2: ptr SigEvent = nil, a3: var Timer): cint
   {.importc, header: "<time.h>".}

proc sigalrm_handler(x: cint) {.noconv.} =
   echo "Timeout!"

proc sigint_handler(x: cint) {.noconv.} =
   echo "Exiting!"
   do_exit = true


echo "Initializing"
var svn_object = new SvnObject
init(svn_object)
open_session(svn_object, "svn://192.168.1.100/home/user/repos/helloworld")
echo get_latest_log(svn_object)
echo get_latest_log(svn_object, "branches")
echo get_log(svn_object, ["trunk"], 5)


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
new_time.it_interval = Timespec(tv_sec: Time(2), tv_nsec: 0)


discard timer_settime(timer, 0, new_time, old_time)

while not do_exit:
   discard sigsuspend(empty_sigset)

destroy(svn_object)
