import strutils

import ./libgit2

type
   GitError* = object of ValueError

   GitRepository* = ref object
      repository: ptr Repository

   GitLogObject* = object
      hash*: string
      timestamp*: int64
      name*, email*, message*: string


var is_initialized: bool = false


proc new_git_error(msg: string, args: varargs[string, `$`]): ref GitError =
   new result
   result.msg = format(msg, args)


proc check_libgit(r: cint) =
   if r < 0:
      let message = $libgit2.error_last()[].message
      raise new_git_error("Git error ($1) '$2'.", r, message)


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


proc find_fetch_head(ref_name, remote_url: cstring, oid: ptr Oid, is_merge: cuint, payload: pointer): cint {.cdecl.} =
   # This callback returns a nonzero value to stop the outer loop.
   if is_merge != 0:
      oid_cpy(cast[ptr Oid](payload), oid)
      return 1
   return 0


proc merge_analysis*(o: GitRepository, branch: string) =
   if is_nil(o.repository):
      raise new_git_error("This Git session is not open.")

   # FIXME: Checkout the target branch

   # Find the object id of the FETCH_HEAD commit for the checked out branch.
   var oid: Oid
   check_libgit(repository_fetchhead_foreach(o.repository, find_fetch_head, addr(oid)))

   # Create an annotated commit to be able to perform a merge analysis.
   var annotated_commit: ptr AnnotatedCommit
   check_libgit(annotated_commit_lookup(addr(annotated_commit), o.repository, addr(oid)))

   var merge_analysis: cuint
   var merge_preference: MergePreference
   check_libgit(merge_analysis(addr(merge_analysis), addr(merge_preference), o.repository,
                               addr(annotated_commit), 1))

   # FIXME: Figure out what this function returns.
   if (merge_analysis and MERGE_ANALYSIS_FASTFORWARD) > 0:
      echo "Fast forward possible"
   elif (merge_analysis and MERGE_ANALYSIS_UP_TO_DATE) > 0:
      echo "Up to date"


iterator walk_new_commits*(o: GitRepository, branch: string): GitLogObject =
   if is_nil(o.repository):
      raise new_git_error("This Git session is not open.")

   # FIXME: Checkout the target branch

   var head: Oid
   check_libgit(reference_name_to_id(addr(head), o.repository, "HEAD"))

   var fetch_head: Oid
   check_libgit(repository_fetchhead_foreach(o.repository, find_fetch_head, addr(fetch_head)))

   var walk: ptr Revwalk
   check_libgit(revwalk_new(addr(walk), o.repository))
   defer:
      revwalk_free(walk)

   revwalk_sorting(walk, SORT_REVERSE)
   check_libgit(revwalk_push(walk, addr(fetch_head)))
   check_libgit(revwalk_hide(walk, addr(head)))

   var oid: Oid
   while revwalk_next(addr(oid), walk) == 0:
      var commit: ptr Commit
      check_libgit(commit_lookup(addr(commit), o.repository, addr(oid)))
      let signature: ptr Signature = commit_author(commit)
      var log = GitLogObject()
      log.message = $commit_message(commit)
      log.hash = $oid_tostr_s(addr(oid))
      log.name = $signature[].name
      log.email = $signature[].email
      log.timestamp = signature.time.time
      commit_free(commit)
      yield log


proc fast_forward*(o: GitRepository) =
   discard
