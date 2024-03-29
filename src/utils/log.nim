import strutils

import ./wordwrap

proc syslog(priority: cint, msg: cstring) {.importc, header: "<syslog.h>".}

const
   LOG_EMERG = cint(0)
   LOG_ALERT = cint(1)
   LOG_CRIT = cint(2)
   LOG_ERR = cint(3)
   LOG_WARNING = cint(4)
   LOG_NOTICE = cint(5)
   LOG_INFO = cint(6)
   LOG_DEBUG = cint(7)

   LOG_KERN = cint(0 shl 3)
   LOG_USER = cint(1 shl 3)
   LOG_MAIL = cint(2 shl 3)
   LOG_DAEMON = cint(3 shl 3)
   LOG_AUTH = cint(4 shl 3)
   LOG_SYSLOG = cint(5 shl 3)
   LOG_LPR = cint(6 shl 3)
   LOG_NEWS = cint(7 shl 3)
   LOG_UUCP = cint(8 shl 3)
   LOG_CRON = cint(9 shl 3)
   LOG_AUTHPRIV = cint(10 shl 3)
   LOG_FTP = cint(11 shl 3)


type LogTarget* = enum
   STDOUT, SYSLOG


var log_target: LogTarget


proc set_log_target*(target: LogTarget) =
   log_target = target


proc info*(msg: string, args: varargs[string, `$`]) =
   if log_target == SYSLOG:
      for line in split_lines(format(msg, args)):
         syslog(LOG_INFO or LOG_DAEMON, cstring(line))
   else:
      let msg_split = split_lines(wrap_words(format(msg, args), 80, true))
      echo "INFO:    " & msg_split[0]
      for i in 1..<len(msg_split):
         echo "         " & msg_split[i]


proc warning*(msg: string, args: varargs[string, `$`]) =
   if log_target == SYSLOG:
      for line in split_lines(format(msg, args)):
         syslog(LOG_WARNING or LOG_DAEMON, cstring(line))
   else:
      let msg_split = split_lines(wrap_words(format(msg, args), 80, true))
      echo "WARNING: " & msg_split[0]
      for i in 1..<len(msg_split):
         echo "         " & msg_split[i]


proc error*(msg: string, args: varargs[string, `$`]) =
   if log_target == SYSLOG:
      for line in split_lines(format(msg, args)):
         syslog(LOG_ERR or LOG_DAEMON, cstring(line))
   else:
      let msg_split = split_lines(wrap_words(format(msg, args), 80, true))
      echo "ERROR:   " & msg_split[0]
      for i in 1..<len(msg_split):
         echo "         " & msg_split[i]


proc abort*(e: typedesc[Exception], msg: string, args: varargs[string, `$`]) =
   error(msg, args)
   raise new_exception(e, format(msg, args))
