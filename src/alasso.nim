import libcurl
import strutils
import json
import uri

type
   AlassoError* = object of Exception

   Repository* = object
      id*: int
      label*, description*, url*, branch*: string
      is_archived*: bool

   Revision* = object
      repository*: int
      revision*, description*: string
      timestamp*: int64


const CURL_TIMEOUT = 10 # Seconds


proc `/`(x, y: string): string =
   result = x & "/" & y


proc new_alasso_error(msg: string, args: varargs[string, `$`]):
      ref AlassoError =
   new result
   result.msg = format(msg, args)


proc check_curl(code: Code) =
   if code != E_OK:
      raise new_alasso_error("CURL failed: " & $easy_strerror(code))


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
      is_archived: get_bool(n["attributes"]["is_archived"])
   )


proc get_repositories*(url: string): seq[Repository] =
   let curl = libcurl.easy_init()
   defer:curl.easy_cleanup()
   var str = ""
   check_curl(curl.easy_setopt(OPT_URL, url / "api" / "repository"))
   check_curl(curl.easy_setopt(OPT_WRITEFUNCTION, on_write))
   check_curl(curl.easy_setopt(OPT_WRITEDATA, addr str))
   check_curl(curl.easy_setopt(OPT_TIMEOUT, CURL_TIMEOUT))
   check_curl(curl.easy_perform())

   let node = json.parse_json(str)
   for r in items(node["data"]):
      add(result, parse_repository(r))


proc get_latest_revision*(repository: int, url: string): int =
   let curl = libcurl.easy_init()
   defer:
      curl.easy_cleanup()
   var str = ""
   let url = url / "api/revision/latest?filter=" & encode_url(format(
      """[{"attribute": "repository", "value": "$1"}]""",
      $repository
   ))
   check_curl(curl.easy_setopt(OPT_URL, url))
   check_curl(curl.easy_setopt(OPT_WRITEFUNCTION, on_write))
   check_curl(curl.easy_setopt(OPT_WRITEDATA, addr str))
   check_curl(curl.easy_setopt(OPT_TIMEOUT, CURL_TIMEOUT))
   check_curl(curl.easy_perform())

   let node = json.parse_json(str)
   if node["data"].kind == JNull:
      result = 0
   else:
      result = parse_int(get_str(node["data"]["attributes"]["revision"])[1..^1])


proc get_json(r: Revision): JsonNode =
   result = %*{
      "data": {
         "type": "revision",
         "attributes": {
            "revision": r.revision,
            "description": r.description,
            "timestamp": $r.timestamp
         },
         "relationships": {
            "repository": {"data": {"id": $r.repository, "type": "repository"}}
         }
      }
   }


proc post_revision*(revision: Revision, url: string) =
   let curl = libcurl.easy_init()
   defer:
      curl.easy_cleanup()
   var list: Pslist
   list = slist_append(list, "content-type: application/vnd.api+json")
   check_curl(curl.easy_setopt(OPT_URL, url / "api" / "revision"))
   check_curl(curl.easy_setopt(OPT_POST, 1))
   check_curl(curl.easy_setopt(OPT_POSTFIELDS, $get_json(revision)))
   check_curl(curl.easy_setopt(OPT_HTTPHEADER, list))
   check_curl(curl.easy_setopt(OPT_WRITEFUNCTION, on_write_ignore))
   check_curl(curl.easy_setopt(OPT_TIMEOUT, CURL_TIMEOUT))
   check_curl(curl.easy_perform())
   slist_free_all(list)
