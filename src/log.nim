import strutils

import ./wordwrap

proc info*(msg: string, args: varargs[string]) =
   let msg_split = wrap_words(format(msg, args), 80, true).split_lines()
   echo "INFO:    " & msg_split[0]
   for m in 1..<len(msg_split):
      echo "         " & msg_split[m]


proc warning*(msg: string, args: varargs[string]) =
   let msg_split = wrap_words(format(msg, args), 80, true).split_lines()
   echo "WARNING: " & msg_split[0]
   for m in 1..<len(msg_split):
      echo "         " & msg_split[m]


proc error*(msg: string, args: varargs[string]) =
   let msg_split = wrap_words(format(msg, args), 80, true).split_lines()
   echo "ERROR:   " & msg_split[0]
   for m in 1..<len(msg_split):
      echo "         " & msg_split[m]


proc abort*(e: typedesc[Exception], msg: string, args: varargs[string, `$`]) =
   error(msg, args)
   raise new_exception(e, format(msg, args))
