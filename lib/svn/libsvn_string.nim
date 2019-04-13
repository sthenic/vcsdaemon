import ../apr/libapr

type
   SvnString* {.bycopy.} = object
      data*: cstring
      len*: AprSize
