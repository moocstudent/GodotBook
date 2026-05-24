extends Node

const PLAYER_SCENE := preload("res://player.tscn")

@onready var menu: Panel = %MenuPanel
@onready var status: Label = %StatusLabel
@onready var info: Label = %InfoLabel
@onready var port_edit: LineEdit = %PortEdit
@onready var addr_edit: LineEdit = %AddrEdit
@onready var host_btn: Button = %HostButton
@onready var join_btn: Button = %JoinButton
@onready var players_node: Node2D = %Players

func _ready() -> void:
	host_btn.pressed.connect(_on_host)
	join_btn.pressed.connect(_on_join)

	# MultiplayerAPI 信号(无论 host/client 都接)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)

# ── 启动:host ─────────────────────────────────────────────────

func _on_host() -> void:
	var port := int(port_edit.text)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, 8)
	if err != OK:
		status.text = "create_server failed: %d" % err
		return
	multiplayer.multiplayer_peer = peer

	menu.hide()
	info.text = "[HOST] listening on port %d · 你是 peer id 1" % port

	# Host 也要给自己 spawn 一个 player
	_spawn_player_for(multiplayer.get_unique_id())

# ── 启动:client ───────────────────────────────────────────────

func _on_join() -> void:
	var port := int(port_edit.text)
	var addr := addr_edit.text.strip_edges()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(addr, port)
	if err != OK:
		status.text = "create_client failed: %d" % err
		return
	multiplayer.multiplayer_peer = peer
	status.text = "connecting to %s:%d ..." % [addr, port]

# ── 服务器侧:新连入的客户端 -> 生成它的角色 ───────────────────

func _on_peer_connected(peer_id: int) -> void:
	info.text += "  · peer joined: %d" % peer_id
	# 只有 server 才负责 spawn(spawn 后 MultiplayerSpawner 自动广播给所有 client)
	if multiplayer.is_server():
		_spawn_player_for(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	info.text += "  · peer left: %d" % peer_id
	if multiplayer.is_server():
		var p := players_node.get_node_or_null(str(peer_id))
		if p:
			p.queue_free()

# ── 客户端侧 ─────────────────────────────────────────────────

func _on_connected_to_server() -> void:
	menu.hide()
	info.text = "[CLIENT] connected · 你是 peer id %d" % multiplayer.get_unique_id()
	# 客户端**不要**自己 spawn,等 server 通过 MultiplayerSpawner 自动 replicate 进来

func _on_server_disconnected() -> void:
	info.text = "[CLIENT] disconnected"
	_cleanup()

func _on_connection_failed() -> void:
	status.text = "connection failed (是否对方还没 Host?)"
	multiplayer.multiplayer_peer = null

# ── 工具 ─────────────────────────────────────────────────────

func _spawn_player_for(peer_id: int) -> void:
	# 只在 server 调用。MultiplayerSpawner 看到 add_child 后,自动通过网络给所有 client 同步生成。
	var p := PLAYER_SCENE.instantiate()
	p.name = str(peer_id)        # 节点名 = peer id,方便后续查找/同步
	# 出生位置 + 颜色由 hash 决定
	p.position = Vector2(150 + (peer_id % 5) * 130, 200 + (peer_id % 3) * 120)
	p.player_color = Color.from_hsv(fmod(peer_id * 0.137, 1.0), 0.7, 1.0)
	players_node.add_child(p, true)   # true = 给节点 name 留作 owner_id 关键

func _cleanup() -> void:
	for c in players_node.get_children():
		c.queue_free()
	multiplayer.multiplayer_peer = null
	menu.show()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_cleanup()
		get_tree().quit()
