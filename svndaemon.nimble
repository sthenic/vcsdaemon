version = "0.1.1"
author = "Marcus Eriksson"
description = "A Linux daemon to track log entries of SVN repositories."
src_dir = "src"
bin = @["svndaemon"]
license = "MIT"

skip_dirs = @["tests"]

requires "nim >= 1.4.6"
requires "libcurl >= 1.0.0"
requires "nimgit2 >= 0.3.4"
