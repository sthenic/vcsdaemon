task build, "Compile the application in release mode.":
   withDir("src"):
      exec("nim c -d:release --passC:-flto --passL:-s --gc:markAndSweep svndaemon")

   rmFile("svndaemon".toExe)
   mvFile("src/svndaemon".toExe, "svndaemon".toExe)
   setCommand "nop"

task debug, "Compile the application in the debug mode.":
   withDir("src"):
      exec("nim c svndaemon")

   rmFile("svndaemon".toExe)
   mvFile("src/svndaemon".toExe, "svndaemon".toExe)
   setCommand "nop"
