import ../lib/svn/libsvn

when is_main_module:
   echo "Initializing"
   var svn_object = new SvnObject
   init(svn_object)
   open_session(svn_object, "svn://192.168.1.100/home/user/repos/helloworld")
   echo get_latest_log(svn_object)
   echo get_latest_log(svn_object, "branches")
   echo get_log(svn_object, ["branches"])
   destroy(svn_object)
