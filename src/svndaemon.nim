import ../lib/svn/libsvn
import posix
import tracker
import cli

# Version information
const VERSION_STR = "v0.1.0"

# Exit codes: negative values are
const ESUCCESS = 0
const EINVAL = -1
const EFORK = -2
const ESIGNAL = -3

var do_exit = false


proc timer_create*(a1: ClockId, a2: ptr SigEvent = nil, a3: var Timer): cint
   {.importc, header: "<time.h>".}


proc sigalrm_handler(x: cint) {.noconv.} =
   discard


proc sigint_handler(x: cint) {.noconv.} =
   do_exit = true


# Parse the arguments and options and return a CLI state object.
var cli_state: CliState
try:
   cli_state = parse_cli()
except CliValueError as e:
   echo e.msg
   quit(EINVAL)

# Parse CLI object state.
if cli_state.print_help:
   # Show help text and exit.
   echo "svndaemon v" & VERSION_STR
   quit(ESUCCESS)
elif cli_state.print_version:
   # Show version information and exit.
   echo VERSION_STR
   quit(ESUCCESS)
elif cli_state.as_daemon:
   let pid = posix.fork()
   if pid < 0:
      echo "Fork process failed."
      quit(EFORK)
   elif pid > 0:
      echo "Daemon created with ", pid, "."
      quit(ESUCCESS)


var timer: Timer
var empty_sigset: Sigset
if sigemptyset(empty_sigset) < 0:
   quit(ESIGNAL)

var alrm_action =
   Sigaction(sa_handler: sigalrm_handler, sa_mask: empty_sigset, sa_flags: 0)
var int_action =
   Sigaction(sa_handler: sigint_handler, sa_mask: empty_sigset, sa_flags: 0)

if sigaction(SIGALRM, alrm_action, nil) < 0:
   quit(ESIGNAL)
if sigaction(SIGINT, int_action, nil) < 0:
   quit(ESIGNAL)
if timer_create(CLOCK_REALTIME, nil, timer) < 0:
   quit(ESIGNAL)

var new_time, old_time: Itimerspec
new_time.it_value = Timespec(tv_sec: Time(10), tv_nsec: 0)
new_time.it_interval = Timespec(tv_sec: Time(10), tv_nsec: 0)
if timer_settime(timer, 0, new_time, old_time) < 0:
   quit(ESIGNAL)

var trackers: seq[RepositoryTracker]
var ecode = ESUCCESS
while not do_exit:
   try:
      create(trackers)
      update(trackers)
      discard sigsuspend(empty_sigset)
   except:
      ecode = ESIGNAL
      break

destroy(trackers)
quit(ecode)
