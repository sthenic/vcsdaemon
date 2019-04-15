import ../apr/libapr
import libsvn_types

when defined(linux):
   const libsvn_time = "libsvn_subr-1.so"
else:
   raise new_exception(Exception, "Only supported on Linux")

proc parse_date*(matched: ptr SvnBoolean, result: ptr AprTime, text: cstring,
                 now: AprTime, pool: ptr AprPool):
   ptr SvnLibError {.cdecl, importc: "svn_parse_date", dynlib: libsvn_time.}
