extends Node
class_name NetBackend

# ╔══════════════════════════════════════════════════════════════╗
# ║  联机后端抽象:Steam P2P 优先,降级到 ENet(本地回环)。        ║
# ║                                                              ║
# ║  Steam P2P(SteamMultiplayerPeer,GodotSteam 提供)好处:       ║
# ║   - 走 Steam 中继 / NAT 穿透,玩家无需端口转发                 ║
# ║   - 用 Steam 大厅匹配(create_lobby / join_lobby)            ║
# ║   - 加密、防 IP 暴露                                          ║
# ║  接口与 demo 17 的高层 MultiplayerAPI **完全一致** —— 只是    ║
# ║  换了底层 peer。所以游戏逻辑一行不改。                          ║
# ╚══════════════════════════════════════════════════════════════╝

signal lobby_created(lobby_id: int)
signal lobby_joined(lobby_id: int)
signal log_line(text: String)

var has_steam := false

func _ready() -> void:
	has_steam = Engine.has_singleton("Steam")
	if has_steam:
		_log("GodotSteam 在场 → 可用 SteamMultiplayerPeer")
	else:
		_log("无 GodotSteam → 降级 ENet(127.0.0.1)")

# ── Host ─────────────────────────────────────────────────────

func host() -> void:
	if has_steam:
		_host_steam()
	else:
		_host_enet()

func _host_steam() -> void:
	var Steam = Engine.get_singleton("Steam")
	# 1) 创建大厅(异步,结果在 lobby_created 回调)
	Steam.lobby_created.connect(_on_steam_lobby_created, CONNECT_ONE_SHOT)
	Steam.createLobby(2, 4)        # 2 = friends-only, 最多 4 人

func _on_steam_lobby_created(result: int, lobby_id: int) -> void:
	if result != 1:        # 1 = k_EResultOK
		_log("createLobby 失败: %d" % result)
		return
	# 2) 用 SteamMultiplayerPeer 作为 host
	var peer = ClassDB.instantiate("SteamMultiplayerPeer")
	peer.create_host(0)
	multiplayer.multiplayer_peer = peer
	_log("Steam 大厅已建: %d(host=peer 1)" % lobby_id)
	lobby_created.emit(lobby_id)

# ── Join ─────────────────────────────────────────────────────

func join(lobby_id: int) -> void:
	if has_steam:
		_join_steam(lobby_id)
	else:
		_join_enet()

func _join_steam(lobby_id: int) -> void:
	var Steam = Engine.get_singleton("Steam")
	Steam.lobby_joined.connect(_on_steam_lobby_joined, CONNECT_ONE_SHOT)
	Steam.joinLobby(lobby_id)

func _on_steam_lobby_joined(lobby_id: int, _perm: int, _locked: bool, response: int) -> void:
	if response != 1:
		_log("joinLobby 失败: %d" % response)
		return
	var Steam = Engine.get_singleton("Steam")
	var owner_id = Steam.getLobbyOwner(lobby_id)
	var peer = ClassDB.instantiate("SteamMultiplayerPeer")
	peer.create_client(owner_id, 0)
	multiplayer.multiplayer_peer = peer
	_log("已加入大厅 %d" % lobby_id)
	lobby_joined.emit(lobby_id)

# ── ENet 降级(无 Steam 时本地测试)──────────────────────────

const PORT := 24555

func _host_enet() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(PORT, 4)
	multiplayer.multiplayer_peer = peer
	_log("[ENet] host on 127.0.0.1:%d" % PORT)
	lobby_created.emit(0)

func _join_enet() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", PORT)
	multiplayer.multiplayer_peer = peer
	_log("[ENet] joining 127.0.0.1:%d" % PORT)
	lobby_joined.emit(0)

func _process(_delta: float) -> void:
	if has_steam:
		Engine.get_singleton("Steam").run_callbacks()

func _log(t: String) -> void:
	log_line.emit(t)
