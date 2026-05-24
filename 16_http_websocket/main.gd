extends Control

# 公开的 echo 服务,任何文本发过去都原样收到。
const WS_URL := "wss://echo.websocket.events"

@onready var url_edit: LineEdit = %UrlEdit
@onready var fetch_btn: Button = %FetchButton
@onready var http_status: Label = %HttpStatusLabel
@onready var http_body: TextEdit = %HttpBody

@onready var ws_status: Label = %WsStatusLabel
@onready var ws_input: LineEdit = %WsInput
@onready var send_btn: Button = %SendButton
@onready var reconnect_btn: Button = %ReconnectButton
@onready var ws_log: TextEdit = %WsLog

var http: HTTPRequest
var ws: WebSocketPeer

# 缓存上一次的连接状态,用来检测变化时打印 log
var _last_ws_state: int = -1

func _ready() -> void:
	# HTTP 必须挂成 SceneTree 节点,内部用 SceneTree 跑异步
	http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_http_done)

	fetch_btn.pressed.connect(_on_fetch)
	send_btn.pressed.connect(_on_send)
	ws_input.text_submitted.connect(func(_t): _on_send())
	reconnect_btn.pressed.connect(_connect_ws)

	_connect_ws()

func _process(_delta: float) -> void:
	# WebSocketPeer 没事件循环,自己 poll
	if ws == null:
		return
	ws.poll()
	var state := ws.get_ready_state()
	if state != _last_ws_state:
		_last_ws_state = state
		ws_status.text = "state: %s" % _ws_state_name(state)
		if state == WebSocketPeer.STATE_OPEN:
			_log("[connected]")
		elif state == WebSocketPeer.STATE_CLOSED:
			var code := ws.get_close_code()
			var reason := ws.get_close_reason()
			_log("[closed] code=%d reason=%s" % [code, reason])

	while ws.get_available_packet_count() > 0:
		var pkt := ws.get_packet()
		_log("recv ← " + pkt.get_string_from_utf8())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

# ── HTTP ──────────────────────────────────────────────────────

func _on_fetch() -> void:
	var url := url_edit.text.strip_edges()
	http_status.text = "requesting: %s" % url
	http_body.text = ""
	# 第二个参数:headers,第三个:method(默认 GET)
	var err := http.request(url, PackedStringArray(["Accept: application/json"]))
	if err != OK:
		http_status.text = "request() failed: %d" % err

func _on_http_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		http_status.text = "result=%d (网络层失败)" % result
		return
	http_status.text = "HTTP %d · %d bytes" % [code, body.size()]
	var text := body.get_string_from_utf8()
	# 试 JSON 美化;不是 JSON 也照原样显示
	var parsed: Variant = JSON.parse_string(text)
	if parsed != null:
		http_body.text = JSON.stringify(parsed, "  ")
	else:
		http_body.text = text

# ── WebSocket ─────────────────────────────────────────────────

func _connect_ws() -> void:
	if ws != null:
		ws.close()
	ws = WebSocketPeer.new()
	_log("[connecting] " + WS_URL)
	var err := ws.connect_to_url(WS_URL)
	if err != OK:
		_log("[error] connect_to_url -> %d" % err)

func _on_send() -> void:
	if ws == null or ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		_log("[skip] not connected")
		return
	var msg := ws_input.text
	if msg.is_empty():
		return
	# send_text() 走 TEXT frame;send() 走 BINARY
	ws.send_text(msg)
	_log("send → " + msg)
	ws_input.text = ""

func _ws_state_name(s: int) -> String:
	match s:
		WebSocketPeer.STATE_CONNECTING: return "CONNECTING"
		WebSocketPeer.STATE_OPEN:       return "OPEN"
		WebSocketPeer.STATE_CLOSING:    return "CLOSING"
		WebSocketPeer.STATE_CLOSED:     return "CLOSED"
		_: return "UNKNOWN(%d)" % s

func _log(line: String) -> void:
	var ts := Time.get_time_string_from_system()
	ws_log.text += "[%s] %s\n" % [ts, line]
	# 自动滚到底部
	ws_log.scroll_vertical = 9999
