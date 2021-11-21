import parseopt
import strutils
import os

import ./log

type
   CliValueError* = object of ValueError

   CliState* = object
      print_help*: bool
      print_version*: bool
      as_daemon*: bool
      alasso_url*: string
      repository_store*: string
      restart_on_timeout*: bool
      restart_on_error*: bool


proc parse_cli*(): CliState =
   result.alasso_url = "http://localhost:5000"
   result.repository_store = absolute_path("./repos")
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
         of "repository-store":
            if len(val) == 0:
               log.abort(CliValueError, "Option --repository-store expects a value.")
            result.repository_store = absolute_path(expand_tilde(normalized_path(val)))
         of "restart-on-timeout":
            result.restart_on_timeout = true
         of "restart-on-error":
            result.restart_on_error = true
         else:
            log.abort(CliValueError, "Unknown option '$1'.", key)

      of cmdEnd:
         log.abort(CliValueError, "Failed to parse options and arguments " &
                                  "This should not have happened.")
