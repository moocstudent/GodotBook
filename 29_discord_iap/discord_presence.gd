extends Node
class_name DiscordPresence

# ╔══════════════════════════════════════════════════════════════╗
# ║  Discord Rich Presence 抽象层                                  ║
# ║                                                              ║
# ║  让好友在 Discord 上看到 "正在玩 XXX · 第 3 关 · 1/4 队伍"。   ║
# ║  需要第三方插件(如 discord-rpc-gdextension 或 godotcord)。    ║
# ║  没插件时 no-op + 打印。                                       ║
# ║                                                              ║
# ║  Discord 后台先建一个 Application 拿 client_id。               ║
# ╚══════════════════════════════════════════════════════════════╝

var _has_rpc := false
var client_id := "0000000000000000000"   # 换成你的 Discord App ID

var current_state := ""
var current_details := ""

func _ready() -> void:
	_has_rpc = Engine.has_singleton("DiscordRPC")
	if _has_rpc:
		var rpc = Engine.get_singleton("DiscordRPC")
		rpc.app_id = int(client_id)
		rpc.initialize()
	else:
		push_warning("无 Discord RPC 插件 → presence 调用 no-op")

func _process(_delta: float) -> void:
	if _has_rpc:
		Engine.get_singleton("DiscordRPC").run_callbacks()

# 设置富存在(典型:大图标 + 状态两行 + 时间戳 + 队伍人数)
func set_presence(details: String, state: String, party_size := 0, party_max := 0) -> void:
	current_details = details
	current_state = state
	if not _has_rpc:
		print("[no-discord] presence: '%s' / '%s' party=%d/%d" % [details, state, party_size, party_max])
		return
	var rpc = Engine.get_singleton("DiscordRPC")
	rpc.details = details            # 第一行,如 "第 3 关 - Boss 战"
	rpc.state = state                # 第二行,如 "组队中"
	rpc.large_image = "game_logo"    # Discord 后台上传的 asset key
	rpc.large_image_text = "My Game"
	rpc.start_timestamp = int(Time.get_unix_time_from_system())
	if party_max > 0:
		rpc.party_size = party_size
		rpc.party_max = party_max
	rpc.refresh()

func clear() -> void:
	if _has_rpc:
		Engine.get_singleton("DiscordRPC").clear()

func backend_name() -> String:
	return "DiscordRPC plugin" if _has_rpc else "none (no-op)"
