import terminal
import strutils

import ../lib/apr/libapr
import ../lib/svn/libsvn


type
   SvnDaemonError* = object of Exception
   SvnObject* = ref object
      pool: ptr AprPool
      session: ptr SvnRaSession
   SvnLogObject* = object
      revision*: SvnRevnum
      timestamp*: int64
      author*, message*: string


proc new_svn_daemon_error(msg: string, args: varargs[string, `$`]):
      ref SvnDaemonError =
   new result
   result.msg = format(msg, args)


proc svn_close_session*(o: var SvnObject) =
   o.session = nil


proc is_session_open(o: SvnObject): bool = not is_nil(o.session)


proc svn_init*(o: var SvnObject) =
   discard libapr.pool_initialize()
   discard libapr.pool_create_ex(addr(o.pool), nil, nil, nil)


proc svn_destroy*(o: var SvnObject) =
   svn_close_session(o)
   pool_destroy(o.pool)
   pool_terminate()


proc prompt_helper(cred: ptr ptr SvnAuthCredSimple;
                   baton: pointer; realm: cstring;
                   username: cstring; may_save: SvnBoolean;
                   pool: ptr AprPool): ptr SvnError {.cdecl.} =
   var ret = cast[ptr SvnAuthCredSimple](palloc(pool, sizeof(SvnAuthCredSimple)))
   echo "Authentication realm: " & $realm
   write(stdout, "Username: ")
   let username = read_line(stdin)
   let password = read_password_from_stdin("Password: ")

   ret.username = username
   ret.password = password
   ret.may_save = may_save

   if not is_nil(cred):
      cred[] = ret

   result = SVN_NO_ERROR


proc svn_open_session*(o: var SvnObject, url: string) =
   if len(url) == 0:
      raise new_svn_daemon_error("No URL specified.")
   if is_session_open(o):
      raise new_svn_daemon_error("An SVN session is already open.")

   # Initialize authentication providers.
   var providers = array_make(o.pool, 1,
                              cast[cint](sizeof(ptr SvnAuthProviderObject)))
   var provider: ptr SvnAuthProviderObject

   # Provider to get/set information from the user's ~/.subversion
   # configuration directory.
   auth_get_simple_provider2(addr(provider), nil, nil, o.pool)
   ARRAY_PUSH(providers, ptr SvnAuthProviderObject) = provider

   # Provider to prompt the user for a username and password.
   auth_get_simple_prompt_provider(addr(provider), prompt_helper, nil, 3, o.pool)
   ARRAY_PUSH(providers, ptr SvnAuthProviderObject) = provider

   var callbacks: ptr SvnRaCallbacks2
   discard ra_create_callbacks(addr(callbacks), o.pool)

   # Initialize the authentication baton.
   var auth_baton: ptr SvnAuthBaton
   auth_open(addr(auth_baton), providers, o.pool);
   callbacks.auth_baton = auth_baton

   if not is_nil(
      ra_open4(addr(o.session), nil, url, nil, callbacks, nil, nil, o.pool)
   ):
      raise new_svn_daemon_error("Failed to open SVN session.")


proc svn_get_latest_revnum*(o: SvnObject): SvnRevnum =
   if not is_session_open(o):
      raise new_svn_daemon_error("An SVN session is not open.")

   if not is_nil(ra_get_latest_revnum(o.session, addr(result), o.pool)):
      raise new_svn_daemon_error("Failed to get revision number.")


proc get_log_object(log_entry: ptr SvnLogEntry, pool: ptr AprPool):
      SvnLogObject =
   result.revision = log_entry.revision
   for k, v in pairs(log_entry.revprops, pool):
      let property = $cast[cstring](k)
      let value = cast[ptr SvnString](v).data
      case property
      of "svn:date":
         var t: AprTime
         var matched: SvnBoolean = SVN_FALSE
         if (
            not is_nil(parse_date(addr(matched), addr(t), value, 0, pool)) or
            matched == SVN_FALSE
         ):
            raise new_svn_daemon_error("Failed to parse time string '$1'.",
                                       value)
         result.timestamp = cast[int64](time_sec(t))
      of "svn:log":
         result.message = $value
      of "svn:author":
         result.author = $value
      else:
         raise new_svn_daemon_error("Unknown revprop '$1'.", property)


proc svn_get_log_cb(baton: pointer, log_entry: ptr SvnLogEntry,
                    pool: ptr AprPool): ptr SvnError {.cdecl.} =
   if is_nil(baton):
      raise new_svn_daemon_error("Invalid reference to memory passed as log " &
                                 "entry baton.")
   add(cast[var seq[SvnLogObject]](baton), get_log_object(log_entry, pool))
   result = SVN_NO_ERROR


proc svn_get_log*(o: var SvnObject, begin, `end`: SvnRevnum,
                  paths: openarray[string]): seq[SvnLogObject] =
   ## Get a sequence of log objects from a range of revisions limited by
   ## ``begin`` and ``end`` (inclusive), filtered by ``paths``.
   if not is_session_open(o):
      raise new_svn_daemon_error("An SVN session is not open.")

   var lpaths = array_make(o.pool, cast[cint](len(paths)),
                           cast[cint](sizeof(cstring)))
   for path in paths:
      ARRAY_PUSH(lpaths, cstring) = path

   if not is_nil(
      ra_get_log2(o.session, lpaths, begin, `end`, 0, SVN_FALSE, SVN_TRUE,
                  SVN_FALSE, nil, svn_get_log_cb, addr(result), o.pool)
   ):
      # TODO: Maybe this is not an error, just return the empty sequence.
      raise new_svn_daemon_error("Failed to get log.")


proc svn_get_log*(o: var SvnObject, begin, `end`: SvnRevnum): seq[SvnLogObject] =
   ## Get a sequence of log objects from a range of revisions limited by
   ## ``begin`` and ``end`` (inclusive).
   result = svn_get_log(o, begin, `end`, [""])


proc svn_get_log*(o: var SvnObject, paths: openarray[string]): seq[SvnLogObject] =
   ## Get a sequence of all log object targeted by ``paths``.
   result = svn_get_log(o, 0, SVN_INVALID_REVNUM, paths)


proc svn_get_log*(o: var SvnObject, revision: SvnRevnum): SvnLogObject =
   ## Get a single log object from a specific ``revision``.
   let tmp = svn_get_log(o, revision, revision)
   if len(tmp) > 0:
      result = tmp[0]


proc svn_get_latest_log*(o: var SvnObject): SvnLogObject =
   ## Get a single log object from the latest revision.
   result = svn_get_log(o, SVN_INVALID_REVNUM)


proc svn_get_latest_log*(o: var SvnObject, path: string): SvnLogObject =
   ## Get a single log object from the latest revision filtered by ``path``.
   let tmp = svn_get_log(o, 0, SVN_INVALID_REVNUM, @[path])
   if len(tmp) > 0:
      result = tmp[^1]


when is_main_module:
   echo "Initializing"
   var svn_object = new SvnObject
   svn_init(svn_object)
   svn_open_session(svn_object, "svn://192.168.1.100/home/user/repos/helloworld")
   echo svn_get_latest_log(svn_object)
   echo svn_get_latest_log(svn_object, "branches")
   echo svn_get_log(svn_object, ["branches"])
   svn_destroy(svn_object)
