import ../apr/libapr

const
   SVN_NO_ERROR* = nil
   SVN_ERR_FS_NOT_FOUND* = AprStatus(160013)
   SVN_TRUE* = 1
   SVN_FALSE* = 0

type
   SvnLibError* {.bycopy.} = object
      apr_err*: AprStatus
      message*: cstring
      child*: ptr SvnLibError
      pool*: ptr AprPool
      file*: cstring
      line*: clong

   SvnRevnum* = clong
   SvnBoolean* = cint
   SvnCancelFunc* = proc (cancel_baton: pointer): ptr SvnLibError {.cdecl.}
   SvnLogEntry* {.bycopy.} = object
      changed_paths*: ptr AprHash
      revision*: SvnRevnum
      revprops*: ptr AprHash
      has_children*: SvnBoolean
      changed_paths2*: ptr AprHash
      non_inheritable*: SvnBoolean
      subtractive_merge*: SvnBoolean
   SvnLogEntryReceiver* =
      proc (baton: pointer, log_entry: ptr SvnLogEntry, pool: ptr AprPool):
         ptr SvnLibError {.cdecl.}

proc error_symbolic_name*(s: AprStatus): cstring
   {.cdecl, importc: "svn_error_symbolic_name", dynlib: "libsvn_subr-1.so".}

const
   SVN_INVALID_REVNUM* = SvnRevnum(-1)
