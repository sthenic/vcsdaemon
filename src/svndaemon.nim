import posix

import ./tracker
import ./utils/log
import ./utils/cli

# Version information
const VERSION_STR = "0.1.0"

# Exit codes: negative values indicate errors.
const ESUCCESS = 0
const EINVAL = -1
const EFORK = -2
const ESIGNAL = -3
const ETIMER = -4
const ECONN = -5

const STATIC_HELP_TEXT = static_read("../help.txt")
let HELP_TEXT = "Svndaemon v" & VERSION_STR & "\n\n" & STATIC_HELP_TEXT

var do_exit = false


proc timer_create*(a1: ClockId, a2: ptr SigEvent = nil, a3: var Timer): cint
   {.importc, header: "<time.h>".}


proc timer_settime*(a1: Timer, a2: cint, a3: var Itimerspec,
                    a4: ptr Itimerspec = nil): cint
   {.importc, header: "<time.h>".}


proc sigalrm_handler(x: cint) {.noconv.} =
   discard


proc sigint_handler(x: cint) {.noconv.} =
   do_exit = true


# Parse the arguments and options and return a CLI state object.
var cli_state: CliState
try:
   cli_state = parse_cli()
except CliValueError:
   quit(EINVAL)

# Parse CLI object state.
if cli_state.print_help:
   # Show help text and exit.
   echo HELP_TEXT
   quit(ESUCCESS)
elif cli_state.print_version:
   # Show version information and exit.
   echo VERSION_STR
   quit(ESUCCESS)
elif cli_state.as_daemon:
   let pid = posix.fork()
   if pid < 0:
      log.error("Fork process failed.")
      quit(EFORK)
   elif pid > 0:
      log.info("Daemon created with PID '$1'.", pid)
      quit(ESUCCESS)
   else:
      # Daemon process uses the syslog facility.
      log.set_log_target(SYSLOG)

# Set up signals and actions.
var empty_sigset: Sigset
if sigemptyset(empty_sigset) < 0:
   quit(ESIGNAL)

var alrm_action = Sigaction(sa_handler: sigalrm_handler, sa_mask: empty_sigset,
                            sa_flags: 0)
var int_action = Sigaction(sa_handler: sigint_handler, sa_mask: empty_sigset,
                           sa_flags: 0)
if sigaction(SIGALRM, alrm_action, nil) < 0:
   quit(ESIGNAL)
if sigaction(SIGINT, int_action, nil) < 0:
   quit(ESIGNAL)
if sigaction(SIGPIPE, int_action, nil) < 0:
   quit(ESIGNAL)

# Set up timer.
var timer: Timer
if timer_create(CLOCK_REALTIME, nil, timer) < 0:
   quit(ETIMER)
var tspec: Itimerspec
tspec.it_value = Timespec(tv_sec: Time(10), tv_nsec: 0)

# Main program loop.
var trackers: seq[RepositoryTracker]
var ecode = ESUCCESS
while not do_exit:
   try:
      create(trackers, cli_state.alasso_url)
      update(trackers, cli_state.alasso_url)
   except TrackerTimeoutError:
      # Break the loop unless --restart-on-timeout is specified.
      if not cli_state.restart_on_timeout:
         ecode = ECONN
         break
   except TrackerFatalError as e:
      # We have to destroy the tracker on a fatal error, libsvn may have
      # emitted a SIGPIPE error requiring us to reset the session.
      destroy(trackers[e.id])
      del(trackers, e.id)
      if not cli_state.restart_on_error:
         ecode = ECONN
         break
   except TrackerError:
      if not cli_state.restart_on_error:
         ecode = ECONN
         break
   except Exception as e:
      log.error("(Unknown) '$1'", e.msg)
      ecode = ECONN
      break

   # Suspend the process until next update.
   if timer_settime(timer, 0, tspec) < 0:
      log.error("Failed to set timer.")
      ecode = ETIMER
      break
   discard sigsuspend(empty_sigset)

log.info("Exit($1)", ecode)
destroy(trackers)
quit(ecode)
