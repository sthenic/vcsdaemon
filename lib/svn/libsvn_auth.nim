import strutils

import ../apr/libapr
import libsvn_types

when defined(linux):
   const libsvn_auth = "libsvn_subr-1.so"
else:
   raise new_exception(Exception, "Only supported on Linux")

type
   SvnAuthBaton* {.bycopy.} = object
   SvnAuthProvider* {.bycopy.} = object
      cred_kind*: cstring
      first_credentials*:
         proc (credentials: ptr pointer, iter_baton: ptr pointer,
               provider_baton: pointer, parameters: ptr AprHash,
               realmstring: cstring, pool: ptr AprPool): ptr SvnError {.cdecl.}
      next_credentials*:
         proc (credentials: ptr pointer, iter_baton: pointer,
               provider_baton: pointer, parameters: ptr AprHash,
               realmstring: cstring, pool: ptr AprPool): ptr SvnError {.cdecl.}
      save_credentials*:
         proc (saved: ptr SvnBoolean, credentials: pointer,
               provider_baton: pointer, parameters: ptr AprHash,
               realmstring: cstring, pool: ptr AprPool): ptr SvnError {.cdecl.}
   SvnAuthProviderObject* {.bycopy.} = object
      vtable*: ptr SvnAuthProvider
      provider_baton*: pointer
   SvnAuthCredSimple* {.bycopy.} = object
      username*: cstring
      password*: cstring
      may_save*: SvnBoolean
   SvnAuthPlaintextPromptFunc* =
      proc (may_save_plaintext: ptr SvnBoolean, realmstring: cstring,
            baton: pointer, pool: ptr AprPool): ptr SvnError {.cdecl.}
   SvnAuthSimplePromptFunc* = proc (cred: ptr ptr SvnAuthCredSimple,
                                    baton: pointer, realm: cstring,
                                    username: cstring, may_save: SvnBoolean,
                                    pool: ptr AprPool): ptr SvnError {.cdecl.}

proc auth_get_simple_provider2*(
   provider: ptr ptr SvnAuthProviderObject,
   plaintext_prompt_func: SvnAuthPlaintextPromptFunc, prompt_baton: pointer,
   pool: ptr AprPool)
   {.cdecl, importc: "svn_auth_get_simple_provider2", dynlib: libsvn_auth.}

proc auth_get_simple_prompt_provider*(
    provider: ptr ptr SvnAuthProviderObject,
    prompt_func: SvnAuthSimplePromptFunc, prompt_baton: pointer,
    retry_limit: cint, pool: ptr AprPool) {.cdecl,
    importc: "svn_auth_get_simple_prompt_provider", dynlib: libsvn_auth.}

proc auth_open*(auth_baton: ptr ptr SvnAuthBaton,
                    providers: ptr AprArrayHeader, pool: ptr AprPool)
   {.cdecl, importc: "svn_auth_open", dynlib: libsvn_auth.}
