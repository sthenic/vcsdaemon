import ../apr/libapr
import libsvn_types
import libsvn_auth
import libsvn_string
import libsvn_io
import libsvn_checksum

when defined(linux):
   const libsvn_ra = "libsvn_ra-1.so"
else:
   raise new_exception(Exception, "Only supported on Linux")

type
   SvnRaGetWcPropFunc* =
      proc (baton: pointer, path: cstring, name: cstring,
            value: ptr ptr SvnString, pool: ptr AprPool): ptr SvnLibError {.cdecl.}
   SvnRaSetWcPropFunc* =
      proc (baton: pointer, path: cstring, name: cstring, value: ptr SvnString,
            pool: ptr AprPool): ptr SvnLibError {.cdecl.}
   SvnRaPushWcPropFunc* =
      proc (baton: pointer, path: cstring, name: cstring,
            value: ptr SvnString, pool: ptr AprPool): ptr SvnLibError {.cdecl.}
   SvnRaInvalidateWcPropFunc* =
      proc (baton: pointer, path: cstring, name: cstring,
            pool: ptr AprPool): ptr SvnLibError {.cdecl.}
   SvnRaGetWcContentsFunc* =
      proc (baton: pointer, contents: ptr ptr SvnStream,
            checksum: ptr SvnChecksum, pool: ptr AprPool): ptr SvnLibError {.cdecl.}
   SvnRaGetClientStringFunc* =
      proc (baton: pointer, name: cstringArray, pool: ptr AprPool):
         ptr SvnLibError {.cdecl.}
   SvnRaProgressNotifyFunc* =
      proc (progress: AprOff, total: AprOff, baton: pointer,
            pool: ptr AprPool) {.cdecl.}
   SvnRaOpenTunnelFunc* =
      proc (request: ptr ptr SvnStream, response: ptr ptr SvnStream,
            close_func: ptr SvnRaCloseTunnelFunc,
            close_baton: ptr pointer, tunnel_baton: pointer,
            tunnel_name: cstring, user: cstring, hostname: cstring, port: cint,
            cancel_func: SvnCancelFunc, cancel_baton: pointer,
            pool: ptr AprPool): ptr SvnLibError {.cdecl.}
   SvnRaCheckTunnelFunc* =
      proc (tunnel_baton: pointer, tunnel_name: cstring): SvnBoolean {.cdecl.}
   SvnRaCloseTunnelFunc* =
      proc (close_baton: pointer, tunnel_baton: pointer) {.cdecl.}
   SvnRaCallbacks2* {.bycopy.} = object
      open_tmp_file*:
         proc (fp: ptr ptr AprFile, callback_baton: pointer,
               pool: ptr AprPool): ptr SvnLibError {.cdecl.}
      auth_baton*: ptr SvnAuthBaton
      get_wc_prop*: SvnRaGetWcPropFunc
      set_wc_prop*: SvnRaSetWcPropFunc
      push_wc_prop*: SvnRaPushWcPropFunc
      invalidate_wc_props*: SvnRaInvalidateWcPropFunc
      progress_func*: SvnRaProgressNotifyFunc
      progress_baton*: pointer
      cancel_func*: SvnCancelFunc
      get_client_string*: SvnRaGetClientStringFunc
      get_wc_contents*: SvnRaGetWcContentsFunc
      check_tunnel_func*: SvnRaCheckTunnelFunc
      open_tunnel_func*: SvnRaOpenTunnelFunc
      tunnel_baton*: pointer
   SvnRaSession* {.bycopy.} = object


proc ra_initialize*(pool: ptr AprPool): ptr SvnLibError
   {.cdecl, importc: "svn_ra_initialize", dynlib: libsvn_ra.}


proc ra_create_callbacks*(callbacks: ptr ptr SvnRaCallbacks2,
                              pool: ptr AprPool): ptr SvnLibError
   {.cdecl, importc: "svn_ra_create_callbacks", dynlib: libsvn_ra.}

proc ra_open4*(session_p: ptr ptr SvnRaSession,
               corrected_url: cstringArray, repos_url: cstring,
               uuid: cstring, callbacks: ptr SvnRaCallbacks2,
               callback_baton: pointer, config: ptr AprHash,
               pool: ptr AprPool): ptr SvnLibError
   {.cdecl, importc: "svn_ra_open4", dynlib: libsvn_ra.}

proc ra_get_latest_revnum*(session: ptr SvnRaSession,
                           latest_revnum: ptr SvnRevnum,
                           pool: ptr AprPool): ptr SvnLibError
   {.cdecl, importc: "svn_ra_get_latest_revnum", dynlib: libsvn_ra.}

proc ra_get_log2*(session: ptr SvnRaSession, paths: ptr AprArrayHeader,
                  start: SvnRevnum, `end`: SvnRevnum, limit: cint,
                  discover_changed_paths: SvnBoolean,
                  strict_node_history: SvnBoolean,
                  include_merged_revisions: SvnBoolean,
                  revprops: ptr AprArrayHeader,
                  receiver: SvnLogEntryReceiver,
                  receiver_baton: pointer,
                  pool: ptr AprPool): ptr SvnLibError
   {.cdecl,  importc: "svn_ra_get_log2", dynlib: libsvn_ra.}
