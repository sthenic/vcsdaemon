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
   defer:
      remote_free(lremote)

   var fetch_options: FetchOptions
   fetch_options.version = 1
   fetch_options.callbacks.version = 1
   fetch_options.prune = FetchPrune.UNSPECIFIED
   fetch_options.update_fetchhead = 1
   fetch_options.download_tags = RemoteAutotagOption.DOWNLOAD_TAGS_UNSPECIFIED
   fetch_options.proxy_opts.version = 1
   fetch_options.custom_headers = StrArray()
   check_libgit(remote_fetch(lremote, nil, addr(fetch_options), "fetch"))


proc find_fetch_head(ref_name, remote_url: cstring, oid: ptr Oid, is_merge: cuint, payload: pointer): cint {.cdecl.} =
   # This callback returns a nonzero value to stop the outer loop.
   if is_merge != 0:
      oid_cpy(cast[ptr Oid](payload), oid)
      return 1
   return 0


proc checkout*(o: GitRepository, branch: string): bool =
   if is_nil(o.repository):
      raise new_git_error("This Git session is not open.")

   var reference: ptr Reference
   var annotated_commit: ptr AnnotatedCommit
   if reference_dwim(addr(reference), o.repository, branch) == 0:
      check_libgit(annotated_commit_from_ref(addr(annotated_commit), o.repository, reference))

   # FIXME: check like guess_refish does
   if is_nil(annotated_commit):
      echo "Guessing remote"
      let remote_guess = "refs/remotes/origin/" & branch
      check_libgit(reference_lookup(addr(reference), o.repository, cstring(remote_guess))) # FIXME: Leaking
      check_libgit(annotated_commit_from_ref(addr(annotated_commit), o.repository, reference))

      if is_nil(annotated_commit):
         raise new_git_error("Is nil!")

   defer:
      reference_free(reference)
      annotated_commit_free(annotated_commit)

   # FIXME: Do we even need the annotated commit?!
   var commit: ptr Commit
   check_libgit(commit_lookup(addr(commit), o.repository, annotated_commit_id(annotated_commit)))
   defer:
      commit_free(commit)

   var checkout_options: CheckoutOptions
   checkout_options.version = 1
   checkout_options.checkout_strategy = CHECKOUT_FORCE # FIXME: Set to safe

   check_libgit(checkout_tree(o.repository, cast[ptr Object](commit), addr(checkout_options)))

   # Update HEAD
   var target_head: cstring
   if reference_is_remote(reference) == 1:
      # FIXME: create branch from annotated, set target_head to git_reference_name(branch...)
      var branch_reference: ptr Reference
      check_libgit(branch_create_from_annotated(addr(branch_reference), o.repository, branch, annotated_commit, 0.cint))
      let upstream_name = "origin/" & branch
      check_libgit(branch_set_upstream(branch_reference, cstring(upstream_name)))
      target_head = reference_name(branch_reference)
      reference_free(branch_reference)
      result = true
   else:
      target_head = reference_name(reference)
      result = false

   echo format("Target head: '$1'", target_head)

   check_libgit(repository_set_head(o.repository, target_head))


proc fastforward*(o: GitRepository) =
   if is_nil(o.repository):
      raise new_git_error("This Git session is not open.")
   ## Fast-forward the currently checked out branch to the current FETCH_HEAD.
   var head_reference: ptr Reference
   check_libgit(repository_head(addr(head_reference), o.repository))
   defer:
      reference_free(head_reference)

   var fetch_head_oid: Oid
   check_libgit(repository_fetchhead_foreach(o.repository, find_fetch_head, addr(fetch_head_oid)))

   var fetch_head_obj: ptr Object
   check_libgit(object_lookup(addr(fetch_head_obj), o.repository, addr(fetch_head_oid), ObjectType.COMMIT))
   defer:
      object_free(fetch_head_obj)

   var checkout_options: CheckoutOptions
   checkout_options.version = 1
   checkout_options.checkout_strategy = CHECKOUT_FORCE # FIXME: Set to safe

   check_libgit(checkout_tree(o.repository, fetch_head_obj, addr(checkout_options)))

   var new_head_reference: ptr Reference
   check_libgit(reference_set_target(addr(new_head_reference), head_reference, addr(fetch_head_oid), nil))
   reference_free(new_head_reference)


proc merge_analysis*(o: GitRepository, branch: string): bool =
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
      result = true
   elif (merge_analysis and MERGE_ANALYSIS_UP_TO_DATE) > 0:
      result = false


iterator walk_new_commits*(o: GitRepository, branch: string, full: bool = false): GitLogObject =
   if is_nil(o.repository):
      raise new_git_error("This Git session is not open.")

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
   if not full:
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


iterator walk_commits*(o: GitRepository, start, stop: string): GitLogObject =
   if is_nil(o.repository):
      raise new_git_error("This Git session is not open.")

   var walk: ptr Revwalk
   check_libgit(revwalk_new(addr(walk), o.repository))
   defer:
      revwalk_free(walk)

   revwalk_sorting(walk, SORT_REVERSE)
   check_libgit(revwalk_push_range(walk, cstring(start & ".." & stop)))

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

