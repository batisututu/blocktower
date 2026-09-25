extends Node
## 개발 서버는 adb reverse로 연결하며 외부 서버에는 HTTPS만 허용한다.
const ACCOUNT_PATH := "user://phase4_account.json"
const SERVER_PATH := "user://phase4_server.txt"
var server_url := "http://127.0.0.1:8765"
var token := ""
var alias := ""

func _ready() -> void:
    if FileAccess.file_exists(SERVER_PATH):
        var saved := FileAccess.get_file_as_string(SERVER_PATH).strip_edges()
        if _valid_url(saved): server_url = saved
    var account: Variant = JSON.parse_string(FileAccess.get_file_as_string(ACCOUNT_PATH)) if FileAccess.file_exists(ACCOUNT_PATH) else null
    if typeof(account) == TYPE_DICTIONARY and account.get("server_url", "") == server_url:
        token = str(account.get("token", ""))
        alias = str(account.get("alias", ""))

func _valid_url(value: String) -> bool:
    var expression := RegEx.new()
    expression.compile("^https://[A-Za-z0-9.-]+(:[0-9]{1,5})?$|^http://(127\\.0\\.0\\.1|localhost)(:[0-9]{1,5})?$")
    return expression.search(value) != null

func configure_server(value: String) -> Dictionary:
    var trimmed := value.strip_edges().trim_suffix("/")
    if not _valid_url(trimmed): return {"ok": false, "error": "HTTPS_REQUIRED"}
    var file := FileAccess.open(SERVER_PATH,FileAccess.WRITE)
    if file == null: return {"ok": false, "error": "SAVE_FAILED"}
    file.store_string(trimmed)
    file.flush()
    var error := file.get_error()
    file.close()
    if error != OK: return {"ok": false, "error": "SAVE_FAILED"}
    if trimmed != server_url:
        server_url = trimmed
        token = ""
        alias = ""
    return {"ok": true}

func _save_account(account: Dictionary) -> Dictionary:
    var file := FileAccess.open(ACCOUNT_PATH,FileAccess.WRITE)
    if file == null: return {"ok": false, "error": "SAVE_FAILED"}
    file.store_string(JSON.stringify({"server_url":server_url,"token":account.token,"alias":account.alias}))
    file.flush()
    var error := file.get_error()
    file.close()
    if error != OK: return {"ok": false, "error": "SAVE_FAILED"}
    token = account.token
    alias = account.alias
    return {"ok": true}

func call_api(method: int, path: String, data: Dictionary = {}, authenticated: bool = false) -> Dictionary:
    if authenticated and token.is_empty(): return {"ok": false, "error": "ACCOUNT_REQUIRED"}
    var request := HTTPRequest.new()
    request.timeout = 35.0
    add_child(request)
    var headers := PackedStringArray(["Content-Type: application/json"])
    if authenticated: headers.append("Authorization: Bearer "+token)
    var sent := request.request(server_url+path,headers,method,JSON.stringify(data) if method == HTTPClient.METHOD_POST else "")
    if sent != OK:
        request.queue_free()
        return {"ok": false, "error": "NETWORK_UNAVAILABLE"}
    var response: Array = await request.request_completed
    request.queue_free()
    if response[0] != HTTPRequest.RESULT_SUCCESS: return {"ok": false, "error": "NETWORK_UNAVAILABLE"}
    var body: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
    if typeof(body) != TYPE_DICTIONARY: return {"ok": false, "error": "INVALID_RESPONSE"}
    if response[1] < 200 or response[1] >= 300: return {"ok": false, "error": str(body.get("error", "SERVER_ERROR"))}
    body["ok"] = true
    return body

func ensure_account() -> Dictionary:
    if not token.is_empty(): return {"ok": true, "alias": alias}
    var account: Dictionary = await call_api(HTTPClient.METHOD_POST,"/v1/accounts/guest",{})
    if not account.ok: return account
    return _save_account(account)
