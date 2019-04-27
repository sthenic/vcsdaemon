import parseopt
import strutils

type
   CliValueError* = object of Exception

   CliState* = object
      print_help*: bool
      print_version*: bool
      as_daemon*: bool
      alasso_url*: string


proc new_cli_error(msg: string, args: varargs[string, `$`]): ref CliValueError =
   new result
   result.msg = format(msg, args)


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
               raise new_cli_error("Option --alasso-url expects a value.")
            result.alasso_url = val
         else:
            raise new_cli_error("Unknown option '$1'.", key)

      of cmdEnd:
         raise new_cli_error("Failed to parse options and arguments " &
                             "This should not have happened.")
