import strutils

import ./libgit2

type
   GitError* = object of ValueError

   GitObject* = ref object
      repository: PGitRepository
      is_initialized: bool

   GitLogObject* = object
      hash*: string
      timestamp*: int64
      name*, email*, message*: string


proc new_git_error(msg: string, args: varargs[string, `$`]): ref GitError =
   new result
   result.msg = format(msg, args)


proc check_libgit(r: cint) =
   if r < 0:
      let message = $libgit2.error_last()[].message
      raise new_git_error("Git error ($1) '$2'.", r, message)


proc open*(o: var GitObject, url: string) =
   if len(url) == 0:
      raise new_git_error("No URL specified.")
   if not is_nil(o.repository):
      raise new_git_error("This Git session is already open.")

   check_libgit(repository_open(addr(o.repository), url))


proc close*(o: var GitObject) =
   if not is_nil(o.repository):
      repository_free(o.repository)
   o.repository = nil


proc init*(o: var GitObject) =
   if o.is_initialized:
      raise new_git_error("Git object is already initialized.")

   check_libgit(libgit2.init())
   o.is_initialized = true


proc destroy*(o: var GitObject) =
   if not o.is_initialized:
      raise new_git_error("Git object is not initialized.")

   close(o)
   check_libgit(libgit2.shutdown())
   o.is_initialized = false


proc fetch*(o: GitObject, remote: string) =
   if is_nil(o.repository):
      raise new_git_error("This Git session is not open.")

   var lremote: PGitRemote
   check_libgit(remote_lookup(addr(lremote), o.repository, remote))
   defer:
      remote_free(lremote)

   var fetch_options: GitFetchOptions
   fetch_options.version = 1
   fetch_options.callbacks.version = 1
   fetch_options.prune = GitFetchPrune.UNSPECIFIED
   fetch_options.update_fetchhead = 1
   fetch_options.download_tags = GitRemoteAutotagOption.DOWNLOAD_TAGS_UNSPECIFIED
   fetch_options.proxy_opts.version = 1
   fetch_options.custom_headers = GitStrArray()
   check_libgit(remote_fetch(lremote, nil, addr(fetch_options), "fetch"))


template construct_walker(walk, body: untyped) =
   var walk: PGitRevwalk
   check_libgit(revwalk_new(addr(walk), o.repository))
   defer:
      revwalk_free(walk)

   revwalk_sorting(walk, SORT_REVERSE)
   body

   var oid: GitOid
   while revwalk_next(addr(oid), walk) == 0:
      var commit: PGitCommit
      check_libgit(commit_lookup(addr(commit), o.repository, addr(oid)))
      let signature: ptr GitSignature = commit_author(commit)
      var log = GitLogObject()
      log.message = $commit_message(commit)
      log.hash = $oid
      log.name = $signature[].name
      log.email = $signature[].email
      log.timestamp = signature.time.time
      commit_free(commit)
      yield log


iterator walk_commits*(o: GitObject, remote, branch: string): GitLogObject =
   ## Walk all commits from the first commit up to the current head of `remote/branch`.
   if is_nil(o.repository):
      raise new_git_error("This Git session is not open.")

   construct_walker(walk):
      var head_id: GitOid
      let head_name = "refs/remotes/" & remote & "/" & branch
      check_libgit(reference_name_to_id(addr(head_id), o.repository, cstring(head_name)))
      check_libgit(revwalk_push(walk, addr(head_id)))


iterator walk_commits_range*(o: GitObject, start, stop: string): GitLogObject =
   ## Walk commits in the range `start` to `stop`, excluding `start` and including `stop`.
   if is_nil(o.repository):
      raise new_git_error("This Git session is not open.")

   construct_walker(walk):
      check_libgit(revwalk_push_range(walk, cstring(start & ".." & stop)))
