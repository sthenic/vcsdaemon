import strutils
import os

import ./libgit2

type
   GitError* = object of ValueError

   GitObject* = ref object
      repository: PGitRepository
      is_initialized: bool
      ssh_public_key: string
      ssh_private_key: string
      ssh_passphrase: string

   GitLogObject* = object
      hash*: string
      timestamp*: int64
      name*, email*, message*: string


proc new_git_error(msg: string, args: varargs[string, `$`]): ref GitError =
   new result
   result.msg = format(msg, args)


proc check_libgit(r: cint) =
   if r < 0:
      let error = libgit2.error_last()
      let message = if not is_nil(error):
         $error[].message
      else:
         "<NO MESSAGE>"
      raise new_git_error("Git error ($1) '$2'.", r, message)


proc acquire_credentials(cred: ptr ptr GitCredential, url, username_from_url: cstring,
                         allowed_types: cuint, payload: pointer): cint {.cdecl.} =
   # We only support SSH-based authentication.
   if len(username_from_url) > 0 and (allowed_types and CREDENTIAL_SSH_KEY) > 0:
      if is_nil(payload):
         raise new_git_error("Expected a reference to a Git object but got 'nil'.")

      let ssh_public_key = cast[ptr GitObject](payload)[].ssh_public_key
      let ssh_private_key = cast[ptr GitObject](payload)[].ssh_private_key
      let ssh_passphrase = cast[ptr GitObject](payload)[].ssh_passphrase

      result = credential_ssh_key_new(cred, username_from_url, cstring(ssh_public_key),
                                      cstring(ssh_private_key), cstring(ssh_passphrase))
   else:
      raise new_git_error("Authentication required but either the URL does not contain " &
                          "a username or SSH based authentication is not allowed.")


proc open*(o: var GitObject, url, path, ssh_public_key, ssh_private_key, ssh_passphrase: string) =
   if len(url) == 0:
      raise new_git_error("No URL specified.")
   if not is_nil(o.repository):
      raise new_git_error("This Git session is already open.")

   o.ssh_public_key = ssh_public_key
   o.ssh_private_key = ssh_private_key
   o.ssh_passphrase = ssh_passphrase

   # If the path exists, we try to open the Git repository contained within.
   # Otherwise, we assume that we need to clone a new repository from the
   # provided url.
   if os.dir_exists(path):
      check_libgit(repository_open(addr(o.repository), path))
   else:
      var options: GitCloneOptions
      init(options)
      options.fetch_opts.callbacks.credentials = acquire_credentials
      options.fetch_opts.callbacks.payload = unsafe_addr(o)
      check_libgit(clone(addr(o.repository), url, path, addr(options)))


proc close*(o: var GitObject) =
   if not is_nil(o.repository):
      repository_free(o.repository)
   o.repository = nil


proc init*(o: var GitObject) =
   ## Initialize the Git object ``o``. The caller is expected to call ``destroy``
   ## if an exception is raised.
   if o.is_initialized:
      raise new_git_error("Git object is already initialized.")

   # There's an API incompatiblity between libgit2 v0.28 and any later version.
   # In particular, the git_cred* functions have been renamed to git_credential.
   discard libgit2.init()

   o.is_initialized = true
   var major, minor, rev: cint
   libgit2.version(addr(major), addr(minor), addr(rev))
   if major != libgit2_major or minor != libgit2_minor:
      raise new_git_error("This software is only compatible with libgit2 v$1.$2.x " &
                          "but the linked version of libgit2 is v$3.$4.$5",
                          libgit2_major, libgit2_minor, major, minor, rev)


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
   init(fetch_options)
   fetch_options.callbacks.credentials = acquire_credentials
   fetch_options.callbacks.payload = unsafe_addr(o)
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
      let author_signature: ptr GitSignature = commit_author(commit)
      let committer_signature: ptr GitSignature = commit_committer(commit)
      var log = GitLogObject()
      log.message = $commit_message(commit)
      log.hash = $oid
      log.name = $author_signature[].name
      log.email = $author_signature[].email
      log.timestamp = committer_signature.time.time
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
