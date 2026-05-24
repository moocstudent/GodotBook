extends Node
class_name CloudSync

# ╔══════════════════════════════════════════════════════════════╗
# ║  云同步骨架(把 slot 的 JSON 当 body PUT 到你的服务器)         ║
# ║  本 demo 没有真实服务器,但完整展示客户端这一侧:               ║
# ║   - 同步流程:本地读 → PUT → 等响应                            ║
# ║   - 拉取流程:GET → 解析 → migrate → 写盘                      ║
# ║   - 冲突策略(简版):取 last_modified 较新的一方                ║
# ╚══════════════════════════════════════════════════════════════╝

signal sync_done(success: bool, message: String)

@export var server_base: String = "https://your-backend.example.com/saves"
@export var user_token: String = ""

var _http: HTTPRequest

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)

func push_slot(slot: int, data: Dictionary) -> void:
	var url := "%s/%d" % [server_base, slot]
	var body := JSON.stringify(data)
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + user_token,
	])
	_http.request_completed.connect(_on_push_done, CONNECT_ONE_SHOT)
	var err := _http.request(url, headers, HTTPClient.METHOD_PUT, body)
	if err != OK:
		sync_done.emit(false, "request() err=%d" % err)

func _on_push_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		sync_done.emit(false, "网络层失败 result=%d" % result)
		return
	if code >= 200 and code < 300:
		sync_done.emit(true, "云端写入 OK (HTTP %d)" % code)
	else:
		sync_done.emit(false, "HTTP %d: %s" % [code, body.get_string_from_utf8()])

func pull_slot(slot: int) -> void:
	var url := "%s/%d" % [server_base, slot]
	var headers := PackedStringArray(["Authorization: Bearer " + user_token])
	_http.request_completed.connect(_on_pull_done.bind(slot), CONNECT_ONE_SHOT)
	var err := _http.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		sync_done.emit(false, "request() err=%d" % err)

func _on_pull_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, slot: int) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		sync_done.emit(false, "拉取失败 HTTP %d" % code)
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		sync_done.emit(false, "云端返回不是 JSON 对象")
		return
	var migrated := SaveSystem.migrate(data)

	# 冲突解决:本地 vs 云端,谁的 last_modified 新留谁
	if SaveSystem.slot_exists(slot):
		var local := SaveSystem.load_slot(slot)
		if local.get("last_modified", "") >= migrated.get("last_modified", ""):
			sync_done.emit(true, "本地比云端新,跳过覆盖")
			return

	SaveSystem.save(slot, migrated, true)
	sync_done.emit(true, "已用云端版本覆盖 slot %d" % slot)
