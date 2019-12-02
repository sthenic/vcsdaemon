import libcurl
import strutils
import json
import uri

type
   AlassoError* = object of Exception
   AlassoTimeoutError* = object of AlassoError

   Repository* = object
      id*: int
      label*, description*, url*, branch*, vcs*: string
      is_archived*: bool

   Commit* = object
      repository*, parent*: int
      uid*, message*, author*: string
      timestamp*, author_timestamp*: int64


const CURL_TIMEOUT = 10 # Seconds


proc `/`(x, y: string): string =
   result = x & "/" & y


proc `==`*(x, y: Repository): bool =
   result = (x.id == y.id) and (x.url == y.url) and (x.branch == y.branch)


proc new_alasso_error(msg: string, args: varargs[string, `$`]):
      ref AlassoError =
   new result
   result.msg = format(msg, args)


proc new_alasso_timeout_error(msg: string, args: varargs[string, `$`]):
      ref AlassoTimeoutError =
   new result
   result.msg = format(msg, args)


proc check_curl(code: Code) =
   if code == E_OPERATION_TIMEOUTED:
      raise new_alasso_timeout_error("CURL timeout: " & $easy_strerror(code))
   elif code != E_OK:
      raise new_alasso_error("CURL failed: " & $easy_strerror(code))


proc get_response_code(curl: PCurl): int =
   check_curl(curl.easy_getinfo(INFO_RESPONSE_CODE, addr(result)))


proc on_write(data: ptr char, size: csize, nmemb: csize, user_data: pointer):
      csize =
   var user_data = cast[ptr string](user_data)
   var buffer = new_string(size * nmemb)
   copy_mem(addr buffer[0], data, len(buffer))
   add(user_data[], buffer)
   result = len(buffer).csize


proc on_write_ignore(data: ptr char, size: csize, nmemb: csize,
                     user_data: pointer): csize =
   result = size * nmemb


proc parse_repository(n: JsonNode): Repository =
   result = Repository(
      id: parse_int(get_str(n["id"])),
      label: get_str(n["attributes"]["label"]),
      description: get_str(n["attributes"]["description"]),
      url: get_str(n["attributes"]["url"]),
      branch: get_str(n["attributes"]["branch"]),
      vcs: get_str(n["attributes"]["vcs"]),
      is_archived: get_bool(n["attributes"]["is_archived"])
   )


proc get_repositories*(url: string): seq[Repository] =
   let curl = libcurl.easy_init()
   defer:
      curl.easy_cleanup()
   var str = ""
   check_curl(curl.easy_setopt(OPT_URL,
                               url / "api" / "repository?show_archived=true"))
   check_curl(curl.easy_setopt(OPT_WRITEFUNCTION, on_write))
   check_curl(curl.easy_setopt(OPT_WRITEDATA, addr str))
   check_curl(curl.easy_setopt(OPT_TIMEOUT, CURL_TIMEOUT))
   check_curl(curl.easy_perform())

   let code = curl.get_response_code()
   if code != 200: # Expect 200 OK
      raise new_alasso_error("HTTP request failed: " & $code)

   let node = json.parse_json(str)
   for repository_json in items(node["data"]):
      let repository = parse_repository(repository_json)
      if repository.vcs == "subversion":
         add(result, repository)


proc get_latest_commit*(repository: int, url: string): tuple[revnum, parent: int] =
   let curl = libcurl.easy_init()
   defer:
      curl.easy_cleanup()
   var str = ""
   let url = url / "api/commit/latest?filter=" & encode_url(format(
      """[{"attribute": "repository", "value": "$1"}]""",
      $repository
   ))
   check_curl(curl.easy_setopt(OPT_URL, url))
   check_curl(curl.easy_setopt(OPT_WRITEFUNCTION, on_write))
   check_curl(curl.easy_setopt(OPT_WRITEDATA, addr str))
   check_curl(curl.easy_setopt(OPT_TIMEOUT, CURL_TIMEOUT))
   check_curl(curl.easy_perform())

   let code = curl.get_response_code()
   if code != 200: # Expect 200 OK
      raise new_alasso_error("HTTP request failed: " & $code)

   let node = json.parse_json(str)
   if node["data"].kind == JNull:
      result = (0, 0)
   else:
      result = (
         parse_int(get_str(node["data"]["attributes"]["uid"])[1..^1]),
         parse_int(get_str(node["data"]["id"]))
      )


proc get_json(c: Commit): JsonNode =
   result = %*{
      "data": {
         "type": "commit",
         "attributes": {
            "uid": c.uid,
            "message": c.message,
            "author": c.author,
            "timestamp": $c.timestamp,
            "author_timestamp": $c.author_timestamp
         },
         "relationships": {
            "repository": {"data": {"id": $c.repository, "type": "repository"}}
         }
      }
   }

   # Only include the parent relationship if the commit points to a non-zero id.
   if c.parent > 0:
      result["data"]["relationships"]["parent"] = %*{
         "data": {"id": $c.parent, "type": "commit"}
      }


proc post_commit*(commit: Commit, url: string): int =
   let curl = libcurl.easy_init()

   defer:
      curl.easy_cleanup()
   var list: Pslist
   list = slist_append(list, "content-type: application/vnd.api+json")

   var str = ""
   defer:
      slist_free_all(list)
   check_curl(curl.easy_setopt(OPT_URL, url / "api" / "commit"))
   check_curl(curl.easy_setopt(OPT_POST, 1))
   check_curl(curl.easy_setopt(OPT_POSTFIELDS, $get_json(commit)))
   check_curl(curl.easy_setopt(OPT_HTTPHEADER, list))
   check_curl(curl.easy_setopt(OPT_WRITEFUNCTION, on_write))
   check_curl(curl.easy_setopt(OPT_WRITEDATA, addr str))
   check_curl(curl.easy_setopt(OPT_TIMEOUT, CURL_TIMEOUT))
   check_curl(curl.easy_perform())

   let code = curl.get_response_code()
   if code != 201: # Expect 201 Created
      raise new_alasso_error("HTTP request failed: " & $code)

   let node = json.parse_json(str)
   if node["data"].kind == JNull:
      result = 0
   else:
      result = parse_int(get_str(node["data"]["id"]))
