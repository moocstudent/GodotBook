extends Control

@onready var net: NetBackend = %Net
@onready var backend_label: Label = %BackendLabel
@onready var host_btn: Button = %HostBtn
@onready var join_btn: Button = %JoinBtn
@onready var log_view: TextEdit = %Log

func _ready() -> void:
	await get_tree().process_frame
	backend_label.text = "后端: %s" % ("Steam P2P" if net.has_steam else "ENet (无 GodotSteam,本地回环)")

	net.log_line.connect(_log)
	net.lobby_created.connect(func(id): _log("✓ lobby/server ready (%d)" % id))
	net.lobby_joined.connect(func(id): _log("✓ joined (%d)" % id))

	host_btn.pressed.connect(net.host)
	join_btn.pressed.connect(func(): net.join(0))   # Steam 时真实场景要传大厅 id

	# 高层 MultiplayerAPI 信号(与 demo 17 完全一致)
	multiplayer.peer_connected.connect(func(pid): _log("peer connected: %d" % pid))
	multiplayer.peer_disconnected.connect(func(pid): _log("peer disconnected: %d" % pid))
	multiplayer.connected_to_server.connect(func(): _log("connected_to_server, my id=%d" % multiplayer.get_unique_id()))

func _log(t: String) -> void:
	log_view.text += t + "\n"
	log_view.scroll_vertical = 9999

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
