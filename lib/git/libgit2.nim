when defined(linux):
   const libgit = "libgit2.so"
else:
   raise new_exception(Exception, "Only supported on Linux")

const OID_RAWSZ = 20
const
   SORT_NONE* = 0.cuint
   SORT_TOPOLOGICAL* = (1 shl 0).cuint
   SORT_TIME* = (1 shl 1).cuint
   SORT_REVERSE* = (1 shl 2).cuint

const
   CHECKOUT_NONE* = 0
   CHECKOUT_SAFE* = (1 shl 0).cuint
   CHECKOUT_FORCE* = (1 shl 1).cuint
   CHECKOUT_RECREATE_MISSING* = (1 shl 2).cuint
   CHECKOUT_ALLOW_CONFLICTS* = (1 shl 3).cuint
   CHECKOUT_REMOVE_UNTRACKED* = (1 shl 4).cuint
   CHECKOUT_REMOVE_IGNORED* = (1 shl 5).cuint
   CHECKOUT_UPDATE_ONLY* = (1 shl 6).cuint
   CHECKOUT_DONT_UPDATE_INDEX* = (1 shl 7).cuint
   CHECKOUT_NO_REFRESH* = (1 shl 8).cuint
   CHECKOUT_SKIP_UNMERGED* = (1 shl 9).cuint
   CHECKOUT_USE_OURS* = (1 shl 10).cuint
   CHECKOUT_USE_THEIRS* = (1 shl 11).cuint
   CHECKOUT_DISABLE_PATHSPEC_MATCH* = (1 shl 12).cuint
   CHECKOUT_SKIP_LOCKED_DIRECTORIES* = (1 shl 13).cuint
   CHECKOUT_DONT_OVERWRITE_IGNORED* = (1 shl 14).cuint
   CHECKOUT_CONFLICT_STYLE_MERGE* = (1 shl 15).cuint
   CHECKOUT_CONFLICT_STYLE_DIFF3* = (1 shl 16).cuint
   CHECKOUT_DONT_REMOVE_EXISTING* = (1 shl 17).cuint
   CHECKOUT_DONT_WRITE_INDEX* = (1 shl 18).cuint
   CHECKOUT_UPDATE_SUBMODULES* = (1 shl 19).cuint
   CHECKOUT_UPDATE_SUBMODULES_IF_CHANGED* = (1 shl 20).cuint

const
   CREDENTIAL_USERPASS_PLAINTEXT* = (1 shl 0).cuint
   CREDENTIAL_SSH_KEY* = (1 shl 1).cuint
   CREDENTIAL_SSH_CUSTOM* = (1 shl 2).cuint
   CREDENTIAL_DEFAULT* = (1 shl 3).cuint
   CREDENTIAL_SSH_INTERACTIVE* = (1 shl 4).cuint
   CREDENTIAL_USERNAME* = (1 shl 5).cuint
   CREDENTIAL_SSH_MEMORY* = (1 shl 6).cuint

type
   PGitRepository* = ptr object
   PGitRemote* = ptr object
   PGitRevwalk* = ptr object
   PGitTransport* = ptr object
   PGitCommit* = ptr object

   GitOid* {.bycopy.} = object
      id: array[OID_RAWSZ, uint8]

   GitTransportMessageCb* =
      proc (str: cstring, len: cint, payload: pointer): cint {.cdecl.}

   GitRemoteCompletionType* {.pure.} = enum
      REMOTE_COMPLETION_DOWNLOAD = 0
      REMOTE_COMPLETION_INDEXING = 1
      REMOTE_COMPLETION_ERROR = 2

   GitCred* {.bycopy.} = object
      credtype*: cuint
      free*: proc (cred: ptr GitCred) {.cdecl.}

   GitCredAcquireCb* =
      proc (cred: ptr ptr GitCred, url, username_from_url: cstring, allowed_types: cuint,
            payload: pointer): cint {.cdecl.}

   GitCertType* {.pure.} = enum
      NONE = 0
      X509 = 1
      HOSTKEY_LIBSSH2 = 2
      STRARRAY = 3

   GitCert* {.bycopy.} = object
      cert_type*: GitCertType

   GitTransportCertificateCheckCb* =
      proc (GitCert: ptr GitCert, valid: cint, host: cstring, payload: pointer): cint {.cdecl.}

   GitTransferProgress* {.bycopy.} = object
      total_objects*: cuint
      indexed_objects*: cuint
      received_objects*: cuint
      local_objects*: cuint
      total_deltas*: cuint
      indexed_deltas*: cuint
      received_bytes*: csize_t

   GitTransferProgressCb* =
      proc (stats: ptr GitTransferProgress, payload: pointer): cint {.cdecl.}

   GitPackbuilderProgress* =
      proc (stage: cint, current: uint32, total: uint32, payload: pointer): cint {.cdecl.}

   GitPushTransferProgress* =
      proc (current: cuint, total: cuint, bytes: csize_t, payload: pointer): cint {.cdecl.}

   GitPushUpdate* {.bycopy.} = object
      src_refname*: cstring
      dst_refname*: cstring
      src*: GitOid
      dst*: GitOid

   GitPushNegotiation* =
      proc (updates: ptr ptr GitPushUpdate, len: csize_t, payload: pointer): cint {.cdecl.}

   GitTransportCb* =
      proc (`out`: ptr PGitTransport, owner: PGitRemote, param: pointer): cint {.cdecl.}

   GitRemoteCallbacks* {.bycopy.} = object
      version*: cuint
      sideband_progress*: GitTransportMessageCb
      completion*: proc (`type`: GitRemoteCompletionType, data: pointer): cint {.cdecl.}
      credentials*: GitCredAcquireCb
      certificate_check*: GitTransportCertificateCheckCb
      transfer_progress*: GitTransferProgressCb
      update_tips*: proc (refname: cstring, a: ptr GitOid, b: ptr GitOid, data: pointer): cint {.cdecl.}
      pack_progress*: GitPackbuilderProgress
      push_transfer_progress*: GitPushTransferProgress
      push_update_reference*: proc (refname: cstring, status: cstring, data: pointer): cint {.cdecl.}
      push_negotiation*: GitPushNegotiation
      transport*: GitTransportCb
      payload*: pointer

   GitFetchPrune* {.pure.} = enum
      UNSPECIFIED = 0
      PRUNE = 1
      NO_PRUNE = 2

   GitRemoteAutotagOption* {.pure.} = enum
      DOWNLOAD_TAGS_UNSPECIFIED = 0
      DOWNLOAD_TAGS_AUTO = 1
      DOWNLOAD_TAGS_NONE = 2
      DOWNLOAD_TAGS_ALL = 3

   GitProxy* {.pure.} = enum
      NONE = 0
      AUTO = 1
      SPECIFIED = 2

   GitProxyOptions* {.bycopy.} = object
      version*: cuint
      `type`*: GitProxy
      url*: cstring
      credentials*: GitCredAcquireCb
      certificate_check*: GitTransportCertificateCheckCb
      payload*: pointer

   GitStrArray* {.bycopy.} = object
      strings: cstringArray
      count: csize_t

   GitFetchOptions* {.bycopy.} = object
      version*: cint
      callbacks*: GitRemoteCallbacks
      prune*: GitFetchPrune
      update_fetchhead*: cint
      download_tags*: GitRemoteAutotagOption
      proxy_opts*: GitProxyOptions
      custom_headers*: GitStrArray

   GitTime* {.bycopy.} = object
      # Seconds since epoch.
      time*: int64
      # Timezone offset, in minutes.
      offset*: cint

   GitSignature* {.bycopy.} = object
      name*: cstring
      email*: cstring
      time*: GitTime

   GitError* {.bycopy.} = object
      message*: cstring
      klass*: cint

   GitCheckoutOptions* {.bycopy.} = object
      version*: cuint
      checkout_strategy*: cuint
      disable_filters*: cint
      dir_mode*: cuint
      file_mode*: cuint
      file_open_flags*: cint
      notify_flags*: cuint
      notify_cb*: pointer
      notify_payload*: pointer
      progress_cb*: pointer
      progress_payload*: pointer
      paths*: GitStrArray
      baseline*: pointer
      baseline_index*: pointer
      target_directory*: cstring
      ancestor_label*: cstring
      our_label*: cstring
      their_label*: cstring
      perfdata_cb*: pointer
      perfdata_payload*: pointer

   GitCloneLocal* {.pure.} = enum
      LocalAuto = 0
      Local = 1
      NoLocal = 2
      LocalNoLinks = 3

   GitCloneOptions* {.bycopy.} = object
      version*: cuint
      checkout_opts*: GitCheckoutOptions
      fetch_opts*: GitFetchOptions
      bare*: cint
      local*: GitCloneLocal
      checkout_branch*: cstring
      repository_cb*: pointer
      repository_cb_payload*: pointer
      remote_cb*: pointer
      remote_cb_payload*: pointer

proc init*(o: var GitRemoteCallbacks) =
   o = GitRemoteCallbacks()
   o.version = 1

proc init*(o: var GitProxyOptions) =
   o = GitProxyOptions()
   o.version = 1

proc init*(o: var GitFetchOptions) =
   o = GitFetchOptions()
   init(o.callbacks)
   init(o.proxy_opts)
   o.version = 1
   o.prune = GitFetchPrune.UNSPECIFIED
   o.download_tags = GitRemoteAutotagOption.DOWNLOAD_TAGS_UNSPECIFIED

proc init*(o: var GitCheckoutOptions) =
   o = GitCheckoutOptions()
   o.version = 1

proc init*(o: var GitCloneOptions) =
   o = GitCloneOptions()
   init(o.checkout_opts)
   init(o.fetch_opts)
   o.version = 1
   o.checkout_opts.checkout_strategy = CHECKOUT_SAFE

proc init*(): cint {.cdecl, importc: "git_libgit2_init", dynlib: libgit.}

proc shutdown*(): cint {.cdecl, importc: "git_libgit2_shutdown", dynlib: libgit.}

proc error_last*(): ptr GitError {.cdecl, importc: "giterr_last", dynlib: libgit.}

proc version*(major, minor, rev: ptr cint)
   {.cdecl, importc: "git_libgit2_version", dynlib: libgit.}

proc credential_ssh_key_from_agent*(`out`: ptr ptr GitCred, username: cstring): cint
   {.cdecl, importc: "git_cred_ssh_key_from_agent", dynlib: libgit.}

proc credential_ssh_key_new*(`out`: ptr ptr GitCred, username, publickey, privatekey, passphrase: cstring): cint
   {.cdecl, importc: "git_cred_ssh_key_new", dynlib: libgit.}

proc credential_userpass_plaintext_new*(`out`: ptr ptr GitCred, username, password: cstring): cint
   {.cdecl, importc: "git_cred_userpass_plaintext_new", dynlib: libgit.}

proc credential_username_new*(`out`: ptr ptr GitCred, username: cstring): cint
   {.cdecl, importc: "git_cred_username_new", dynlib: libgit.}

proc clone*(`out`: ptr PGitRepository, url, path: cstring, options: ptr GitCloneOptions): cint
   {.cdecl, importc: "git_clone", dynlib: libgit.}

proc repository_open*(`out`: ptr PGitRepository, path: cstring): cint
   {.cdecl, importc: "git_repository_open", dynlib: libgit.}

proc repository_free*(r: PGitRepository)
   {.cdecl, importc: "git_repository_free", dynlib: libgit.}

proc remote_lookup*(`out`: ptr PGitRemote, repository: PGitRepository, name: cstring): cint
   {.cdecl, importc: "git_remote_lookup", dynlib: libgit.}

proc remote_fetch*(remote: PGitRemote, refspecs: ptr GitStrArray, opts: ptr GitFetchOptions,
                   reflog_message: cstring): cint
   {.cdecl, importc: "git_remote_fetch", dynlib: libgit.}

proc remote_free*(r: PGitRemote)
   {.cdecl, importc: "git_remote_free", dynlib: libgit.}

proc commit_lookup*(commit: ptr PGitCommit, repository: PGitRepository, id: ptr GitOid): cint
   {.cdecl, importc: "git_commit_lookup", dynlib: libgit.}

proc commit_message*(commit: PGitCommit): cstring
   {.cdecl, importc: "git_commit_message", dynlib: libgit.}

proc commit_author*(commit: PGitCommit): ptr GitSignature
   {.cdecl, importc: "git_commit_author", dynlib: libgit.}

proc commit_free*(r: PGitCommit)
   {.cdecl, importc: "git_commit_free", dynlib: libgit.}

proc reference_name_to_id*(`out`: ptr GitOid, repository: PGitRepository, name: cstring): cint
   {.cdecl, importc: "git_reference_name_to_id", dynlib: libgit.}

proc revwalk_new*(`out`: ptr PGitRevwalk, repository: PGitRepository): cint
   {.cdecl, importc: "git_revwalk_new", dynlib: libgit.}

proc revwalk_sorting*(walk: PGitRevwalk, sort_mode: cuint)
   {.cdecl, importc: "git_revwalk_sorting", dynlib: libgit.}

proc revwalk_next*(`out`: ptr GitOid, walk: PGitRevwalk): cint
   {.cdecl, importc: "git_revwalk_next", dynlib: libgit.}

proc revwalk_free*(r: PGitRevwalk)
   {.cdecl, importc: "git_revwalk_free", dynlib: libgit.}

proc revwalk_push*(walk: PGitRevwalk, id: ptr GitOid): cint
   {.cdecl, importc: "git_revwalk_push", dynlib: libgit.}

proc revwalk_push_range*(walk: PGitRevwalk, r: cstring): cint
   {.cdecl, importc: "git_revwalk_push_range", dynlib: libgit.}

proc oid_tostr_s(oid: ptr GitOid): cstring
   {.cdecl, importc: "git_oid_tostr_s", dynlib: libgit.}

proc `$`*(oid: GitOid): string = $oid_tostr_s(unsafeaddr(oid))
