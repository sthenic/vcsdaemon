import parseopt
import strutils

type
   CliValueError* = object of Exception

   CliState* = object
      print_help*: bool
      print_version*: bool
      as_daemon*: bool


proc new_cli_error(msg: string, args: varargs[string, `$`]): ref CliValueError =
   new result
   result.msg = format(msg, args)


proc parse_cli*(): CliState =
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
         else:
            raise new_cli_error("Unknown option '$1'.", key)

      of cmdEnd:
         raise new_cli_error("Failed to parse options and arguments " &
                             "This should not have happened.")
