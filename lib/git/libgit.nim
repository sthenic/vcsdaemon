import strutils

import ./libgit2

type
   GitError* = object of ValueError

   GitRepository* = ref object
      repository: ptr Repository

   GitLogObject* = object
      hash*: string
      timestamp*: int64
      author*, message*: string


var is_initialized: bool = false


proc new_git_error(msg: string, args: varargs[string, `$`]): ref GitError =
   new result
   result.msg = format(msg, args)


proc check_libgit(result: cint) =
   if result < 0:
      let message = $libgit2.error_last()[].message
      raise new_git_error("Git error '$1'.", message)


proc init*() =
   if is_initialized:
      raise new_git_error("libgit is already initialized.")

   check_libgit(libgit2.init())
   is_initialized = true


proc shutdown*() =
   if not is_initialized:
      raise new_git_error("libgit is not initialized.")

   check_libgit(libgit2.shutdown())
   is_initialized = false


proc open*(o: var GitRepository, url: string) =
   if len(url) == 0:
      raise new_git_error("No URL specified.")
   if not is_nil(o.repository):
      raise new_git_error("This Git session is already open.")

   check_libgit(repository_open(addr(o.repository), url))


proc close*(o: var GitRepository) =
   if is_nil(o.repository):
      raise new_git_error("This Git session is not open.")

   repository_free(o.repository)
   o.repository = nil


proc fetch*(o: GitRepository, remote: string) =
   if is_nil(o.repository):
      raise new_git_error("This Git session is not open.")

   var lremote: ptr Remote
   check_libgit(remote_lookup(addr(lremote), o.repository, remote))

   var fetch_options: FetchOptions
   fetch_options.version = 1
   fetch_options.callbacks.version = 1
   fetch_options.prune = FetchPrune.UNSPECIFIED
   fetch_options.update_fetchhead = 1
   fetch_options.download_tags = RemoteAutotagOption.DOWNLOAD_TAGS_UNSPECIFIED
   fetch_options.proxy_opts.version = 1
   fetch_options.custom_headers = StrArray()
   try:
      check_libgit(remote_fetch(lremote, nil, addr(fetch_options), "fetch"))
   finally:
      remote_free(lremote)
