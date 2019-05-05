import parseopt
import strutils

import ./log

type
   CliValueError* = object of Exception

   CliState* = object
      print_help*: bool
      print_version*: bool
      as_daemon*: bool
      alasso_url*: string
      restart_on_timeout*: bool


proc parse_cli*(): CliState =
   result.alasso_url = "http://localhost:5000"
   var p = init_opt_parser()
   for kind, key, val in p.getopt():
      case kind:
      of cmdArgument:
         discard

      of cmdLongOption, cmdShortOption:
         case key:
         of "help", "h":
            result.print_help = true
         of "version", "v":
            result.print_version = true
         of "daemon", "d":
            result.as_daemon = true
         of "alasso-url":
            if len(val) == 0:
               log.abort(CliValueError, "Option --alasso-url expects a value.")
            result.alasso_url = val
         of "restart-on-timeout":
            result.restart_on_timeout = true
         else:
            log.abort(CliValueError, "Unknown option '$1'.", key)

      of cmdEnd:
         log.abort(CliValueError, "Failed to parse options and arguments " &
                                  "This should not have happened.")
