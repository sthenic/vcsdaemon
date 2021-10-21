type
   SvnChecksumKind* {.size: sizeof(cint).} = enum
      SvnChecksumMd5, SvnChecksumSha1, SvnChecksumFnv1a_32,
      SvnChecksumFnv1a_32x4
   SvnChecksum* {.bycopy.} = object
      digest*: ptr uint8
      kind*: SvnChecksumKind
