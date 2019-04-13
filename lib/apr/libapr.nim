when defined(linux):
   const libapr = "libapr-1.so"
else:
   raise new_exception(Exception, "Only supported on Linux")

const
   APR_USEC_PER_SEC = 1000000

type
   AprInt64* = clong
   AprTime* = AprInt64
   AprPool* {.bycopy.} = object
   AprAllocator* {.bycopy.} = object
   AprHash* {.bycopy.} = object
   AprHashIndex* {.bycopy.} = object
   AprFile* {.bycopy.} = object
   AprAbortFunc* = proc (retcode: cint): cint {.cdecl.}
   AprStatus* = cint
   AprSize* = csize
   AprSsize* = clong
   AprOff* = clong
   AprArrayHeader* {.bycopy.} = object
      pool*: ptr AprPool
      elt_size*: cint
      nelts*: cint
      nalloc*: cint
      elts*: cstring

proc pool_initialize*(): AprStatus
   {.cdecl, importc: "apr_pool_initialize", dynlib: libapr.}
proc pool_terminate*()
   {.cdecl, importc: "apr_pool_terminate", dynlib: libapr.}
proc pool_create_ex*(new_pool: ptr ptr AprPool, parent: ptr AprPool,
                     abort_fn: AprAbortFunc, allocator: ptr AprAllocator): AprStatus
   {.cdecl, importc: "apr_pool_create_ex", dynlib: libapr.}
proc pool_destroy*(p: ptr AprPool)
   {.cdecl, importc: "apr_pool_destroy", dynlib: libapr.}
proc palloc*(p: ptr AprPool, size: AprSize): pointer
   {.cdecl, importc: "apr_palloc", dynlib: libapr.}
proc hash_first*(p: ptr AprPool, ht: ptr AprHash): ptr AprHashIndex
   {.cdecl, importc: "apr_hash_first", dynlib: libapr.}
proc hash_next*(hi: ptr AprHashIndex): ptr AprHashIndex
   {.cdecl, importc: "apr_hash_next", dynlib: libapr.}
proc hash_this*(hi: ptr AprHashIndex, key: ptr pointer, klen: ptr AprSsize,
                val: ptr pointer)
   {.cdecl, importc: "apr_hash_this", dynlib: libapr.}
proc array_make*(p: ptr AprPool, nelts, elt_size: cint): ptr AprArrayHeader
   {.cdecl, importc: "apr_array_make", dynlib: libapr.}
proc array_push*(arr: ptr AprArrayHeader): pointer
   {.cdecl, importc: "apr_array_push", dynlib: libapr.}

template time_sec*(time: untyped): untyped =
  ((time) div APR_USEC_PER_SEC)

template ARRAY_PUSH*(ary, `type`: untyped): untyped =
  ((cast[ptr `type`](array_push(ary)))[])

iterator pairs*(hash: ptr AprHash, p: ptr AprPool): tuple[key, val: pointer] =
   var hi = hash_first(p, hash)
   while not is_nil(hi):
      var key, val: pointer
      hash_this(hi, addr(key), nil, addr(val))
      yield (key, val)
      hi = hash_next(hi)
