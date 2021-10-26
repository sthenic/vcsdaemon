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
   MERGE_ANALYSIS_NONE* = 0.cuint
   MERGE_ANALYSIS_NORMAL* = (1 shl 0).cuint
   MERGE_ANALYSIS_UP_TO_DATE* = (1 shl 1).cuint
   MERGE_ANALYSIS_FASTFORWARD* = (1 shl 2).cuint
   MERGE_ANALYSIS_UNBORN* = (1 shl 3).cuint

type
   Repository* = object
   Remote* = object
   Object* = object
   AnnotatedCommit* = object
   Revwalk* = object
   Reference* = object
   Transport* = object
   Tree* = object
   Index* = object
   Commit* = object

   Oid* {.bycopy.} = object
      id: array[OID_RAWSZ, uint8]

   TransportMessageCb* =
      proc (str: cstring, len: cint, payload: pointer): cint {.cdecl.}

   RemoteCompletionType* {.pure.} = enum
      REMOTE_COMPLETION_DOWNLOAD = 0
      REMOTE_COMPLETION_INDEXING = 1
      REMOTE_COMPLETION_ERROR = 2

   CredType* {.pure.} = enum
      USERPASS_PLAINTEXT = (1 shl 0)
      SSH_KEY = (1 shl 1)
      SSH_CUSTOM = (1 shl 2)
      DEFAULT = (1 shl 3)
      SSH_INTERACTIVE = (1 shl 4)
      USERNAME = (1 shl 5)
      SSH_MEMORY = (1 shl 6)

   Cred* {.bycopy.} = object
      credtype*: CredType
      free*: proc (cref: ptr Cred) {.cdecl.}

   CredAcquireCb* =
      proc (cred: ptr ptr Cred, url, username_from_url: cstring, allowed_types: cuint,
            payload: pointer): cint {.cdecl.}

   CertType* {.pure.} = enum
      NONE = 0
      X509 = 1
      HOSTKEY_LIBSSH2 = 2
      STRARRAY = 3

   Cert* {.bycopy.} = object
      cert_type*: CertType

   TransportCertificateCheckCb* =
      proc (cert: ptr Cert, valid: cint, host: cstring, payload: pointer): cint {.cdecl.}

   TransferProgress* {.bycopy.} = object
      total_objects*: cuint
      indexed_objects*: cuint
      received_objects*: cuint
      local_objects*: cuint
      total_deltas*: cuint
      indexed_deltas*: cuint
      received_bytes*: csize_t

   TransferProgressCb* =
      proc (stats: ptr TransferProgress, payload: pointer): cint {.cdecl.}

   PackbuilderProgress* =
      proc (stage: cint, current: uint32, total: uint32, payload: pointer): cint {.cdecl.}

   PushTransferProgress* =
      proc (current: cuint, total: cuint, bytes: csize_t, payload: pointer): cint {.cdecl.}

   PushUpdate* {.bycopy.} = object
      src_refname*: cstring
      dst_refname*: cstring
      src*: Oid
      dst*: Oid

   PushNegotiation* =
      proc (updates: ptr ptr PushUpdate, len: csize_t, payload: pointer): cint {.cdecl.}

   TransportCb* =
      proc (`out`: ptr ptr Transport, owner: ptr Remote, param: pointer): cint {.cdecl.}

   RemoteCallbacks* {.bycopy.} = object
      version*: cuint
      sideband_progress*: TransportMessageCb
      completion*: proc (`type`: RemoteCompletionType, data: pointer): cint {.cdecl.}
      credentials*: CredAcquireCb
      certificate_check*: TransportCertificateCheckCb
      transfer_progress*: TransferProgressCb
      update_tips*: proc (refname: cstring, a: ptr Oid, b: ptr Oid, data: pointer): cint {.cdecl.}
      pack_progress*: PackbuilderProgress
      push_transfer_progress*: PushTransferProgress
      push_update_reference*: proc (refname: cstring, status: cstring, data: pointer): cint {.cdecl.}
      push_negotiation*: PushNegotiation
      transport*: TransportCb
      payload*: pointer

   FetchPrune* {.pure.} = enum
      UNSPECIFIED = 0
      PRUNE = 1
      NO_PRUNE = 2

   RemoteAutotagOption* {.pure.} = enum
      DOWNLOAD_TAGS_UNSPECIFIED = 0
      DOWNLOAD_TAGS_AUTO = 1
      DOWNLOAD_TAGS_NONE = 2
      DOWNLOAD_TAGS_ALL = 3

   Proxy* {.pure.} = enum
      NONE = 0
      AUTO = 1
      SPECIFIED = 2

   ProxyOptions* {.bycopy.} = object
      version*: cuint
      `type`*: Proxy
      url*: cstring
      credentials*: CredAcquireCb
      certificate_check*: TransportCertificateCheckCb
      payload*: pointer

   StrArray* {.bycopy.} = object
      strings: cstringArray
      count: csize_t

   FetchOptions* {.bycopy.} = object
      version*: cint
      callbacks*: RemoteCallbacks
      prune*: FetchPrune
      update_fetchhead*: cint
      download_tags*: RemoteAutotagOption
      proxy_opts*: ProxyOptions
      custom_headers*: StrArray

   RepositoryFetchheadForeachCb* =
      proc (ref_name, remote_url: cstring, oid: ptr Oid, is_merge: cuint, payload: pointer): cint {.cdecl.}

   MergePreference* {.pure.} = enum
      NONE = 0
      NO_FASTFORWARD = (1 shl 0)
      FASTFORWARD_ONLY = (1 shl 1)

   ObjectType* {.pure.} = enum
      ANY = -2
      BAD = -1
      EXT1 = 0
      COMMIT = 1
      TREE = 2
      BLOB = 3
      TAG = 4
      EXT2 = 5
      OFS_DELTA = 6
      REF_DELTA = 7

   CheckoutNotify* {.pure.} = enum
      NOTIFY_NONE = 0
      NOTIFY_CONFLICT = (1 shl 0)
      NOTIFY_DIRTY = (1 shl 1)
      NOTIFY_UPDATED = (1 shl 2)
      NOTIFY_UNTRACKED = (1 shl 3)
      NOTIFY_IGNORED = (1 shl 4)
      NOTIFY_ALL = 0x0FFFF

   Off = distinct uint64

   DiffFile* {.bycopy.} = object
      id*: Oid
      path*: cstring
      size*: Off
      flags*: uint32
      mode*: uint16
      id_abbrev*: uint16

   CheckoutNotifyCb* =
      proc (why: CheckoutNotify, path: cstring, baseline: ptr DiffFile, target: ptr DiffFile,
            workdir: ptr DiffFile, payload: pointer): cint {.cdecl.}

   CheckoutProgressCb* =
      proc (path: cstring, completed_steps: csize_t, total_steps: csize_t, payload: pointer) {.cdecl.}

   CheckoutPerfdata* {.bycopy.} = object
      mkdir_calls*: csize_t
      stat_calls*: csize_t
      chmod_calls*: csize_t

   CheckoutPerfdataCb* =
      proc (perfdata: ptr CheckoutPerfdata, payload: pointer) {.cdecl.}

   CheckoutOptions* {.bycopy.} = object
      version*: cuint
      checkout_strategy*: cuint
      disable_filters*: cint
      dir_mode*: cuint
      file_mode*: cuint
      file_open_flags*: cint
      notify_flags*: cuint
      notify_cb*: CheckoutNotifyCb
      notify_payload*: pointer
      progress_cb*: CheckoutProgressCb
      progress_payload*: pointer
      paths*: StrArray
      baseline*: ptr Tree
      baseline_index*: ptr Index
      target_directory*: cstring
      ancestor_label*: cstring
      our_label*: cstring
      their_label*: cstring
      perfdata_cb*: CheckoutPerfdataCb
      perfdata_payload*: pointer

   Time* {.bycopy.} = object
      # Seconds since epoch.
      time*: int64
      # Timezone offset, in minutes.
      offset*: cint

   Signature* {.bycopy.} = object
      name*: cstring
      email*: cstring
      time*: Time

   GitError* {.bycopy.} = object
      message*: cstring
      klass*: cint

proc init*(): cint {.cdecl, importc: "git_libgit2_init", dynlib: libgit.}

proc shutdown*(): cint {.cdecl, importc: "git_libgit2_shutdown", dynlib: libgit.}

proc error_last*(): ptr GitError {.cdecl, importc: "giterr_last", dynlib: libgit.}

proc repository_open*(`out`: ptr ptr Repository, path: cstring): cint
   {.cdecl, importc: "git_repository_open", dynlib: libgit.}

proc remote_lookup*(`out`: ptr ptr Remote, repository: ptr Repository, name: cstring): cint
   {.cdecl, importc: "git_remote_lookup", dynlib: libgit.}

proc remote_fetch*(remote: ptr Remote, refspecs: ptr StrArray, opts: ptr FetchOptions,
                   reflog_message: cstring): cint
   {.cdecl, importc: "git_remote_fetch", dynlib: libgit.}

proc repository_fetchhead_foreach*(repository: ptr Repository,
                                   callback: RepositoryFetchheadForeachCb, payload: pointer): cint
   {.cdecl, importc: "git_repository_fetchhead_foreach", dynlib: libgit.}

proc reference_name_to_id*(`out`: ptr Oid, repository: ptr Repository, name: cstring): cint
   {.cdecl, importc: "git_reference_name_to_id", dynlib: libgit.}

# FIXME: Wrap into stringify
proc oid_tostr_s*(oid: ptr Oid): cstring
   {.cdecl, importc: "git_oid_tostr_s", dynlib: libgit.}

proc oid_cpy*(`out`, src: ptr Oid)
   {.cdecl, importc: "git_oid_cpy", dynlib: libgit.}

proc annotated_commit_lookup*(`out`: ptr ptr AnnotatedCommit, repository: ptr Repository, id: ptr Oid): cint
   {.cdecl, importc: "git_annotated_commit_lookup", dynlib: libgit.}

proc merge_analysis*(analysis_out: ptr cuint, preference_out: ptr MergePreference,
                     repository: ptr Repository, their_heads: ptr ptr AnnotatedCommit,
                     their_heads_len: csize_t): cint
   {.cdecl, importc: "git_merge_analysis", dynlib: libgit.}

proc revwalk_new*(`out`: ptr ptr Revwalk, repository: ptr Repository): cint
   {.cdecl, importc: "git_revwalk_new", dynlib: libgit.}

proc revwalk_sorting*(walk: ptr Revwalk, sort_mode: cuint)
   {.cdecl, importc: "git_revwalk_sorting", dynlib: libgit.}

proc revwalk_push*(walk: ptr Revwalk, id: ptr Oid): cint
   {.cdecl, importc: "git_revwalk_push", dynlib: libgit.}

proc revwalk_hide*(walk: ptr Revwalk, commit_id: ptr Oid): cint
   {.cdecl, importc: "git_revwalk_hide", dynlib: libgit.}

# FIXME: Wrap into iterator
proc revwalk_next*(`out`: ptr Oid, walk: ptr Revwalk): cint
   {.cdecl, importc: "git_revwalk_next", dynlib: libgit.}

proc repository_head*(`out`: ptr ptr Reference, repository: ptr Repository): cint
   {.cdecl, importc: "git_repository_head", dynlib: libgit.}

proc object_lookup*(`object`: ptr ptr Object, repository: ptr Repository, id: ptr Oid, `type`: ObjectType): cint
   {.cdecl, importc: "git_object_lookup", dynlib: libgit.}

proc checkout_tree*(repository: ptr Repository, treeish: ptr Object, opts: ptr CheckoutOptions): cint
   {.cdecl, importc: "git_checkout_tree", dynlib: libgit.}

proc reference_set_target*(`out`: ptr ptr Reference, reference: ptr Reference, id: ptr Oid, log_message: cstring): cint
   {.cdecl, importc: "git_reference_set_target", dynlib: libgit.}

proc commit_lookup*(commit: ptr ptr Commit, repository: ptr Repository, id: ptr Oid): cint
   {.cdecl, importc: "git_commit_lookup", dynlib: libgit.}

proc commit_message*(commit: ptr Commit): cstring
   {.cdecl, importc: "git_commit_message", dynlib: libgit.}

proc commit_author*(commit: ptr Commit): ptr Signature
   {.cdecl, importc: "git_commit_author", dynlib: libgit.}

proc object_free*(o: ptr Object)
   {.cdecl, importc: "git_object_free", dynlib: libgit.}

proc remote_free*(r: ptr Remote)
   {.cdecl, importc: "git_remote_free", dynlib: libgit.}

proc reference_free*(r: ptr Reference)
   {.cdecl, importc: "git_reference_free", dynlib: libgit.}

proc repository_free*(r: ptr Repository)
   {.cdecl, importc: "git_repository_free", dynlib: libgit.}

proc annotated_commit_free*(r: ptr AnnotatedCommit)
   {.cdecl, importc: "git_annotated_commit_free", dynlib: libgit.}

proc commit_free*(r: ptr Commit)
   {.cdecl, importc: "git_commit_free", dynlib: libgit.}

proc revwalk_free*(r: ptr Revwalk)
   {.cdecl, importc: "git_revwalk_free", dynlib: libgit.}
