extends Node
# Autoload 候选:把这个脚本设为 Autoload 单例名 "Steam_"(避免和 GodotSteam 的 Steam 冲突)
# 或直接 class_name 用。本 demo 作为普通节点用。

# ╔══════════════════════════════════════════════════════════════╗
# ║  GodotSteam 包装层 + 优雅降级                                   ║
# ║                                                              ║
# ║  GodotSteam 是第三方 GDExtension(把 Steamworks SDK 暴露给     ║
# ║  GDScript)。没装它时,这个 wrapper 全部 no-op,游戏照样能跑    ║
# ║  (开发期 / 非 Steam 版本 / itch.io 版本)。                    ║
# ║                                                              ║
# ║  真实集成时:                                                  ║
# ║   1) 下载 GodotSteam 预编译版放 addons/                       ║
# ║   2) 项目根放 steam_appid.txt(内容 = 你的 App ID,480=测试)  ║
# ║   3) 这个 wrapper 里把 _has_steam 改成检测 ClassDB             ║
# ╚══════════════════════════════════════════════════════════════╝

signal achievement_unlocked(api_name: String)
signal stats_received()

var _has_steam := false
var _app_id := 480           # 480 = Spacewar,Steamworks 官方测试 App
var steam_id := 0
var steam_name := "(offline)"

func _ready() -> void:
	# GodotSteam 装好后,会注册一个全局 "Steam" 单例类
	_has_steam = Engine.has_singleton("Steam")
	if _has_steam:
		_init_steam()
	else:
		push_warning("GodotSteam 未安装 —— 所有 Steam 调用将 no-op(开发模式)")

func _init_steam() -> void:
	var Steam = Engine.get_singleton("Steam")
	var init_result = Steam.steamInitEx()       # 返回字典 {status, verbal}
	if init_result["status"] != 0:
		push_error("Steam init failed: " + str(init_result["verbal"]))
		_has_steam = false
		return
	steam_id = Steam.getSteamID()
	steam_name = Steam.getPersonaName()
	# Steam 回调要每帧 pump
	Steam.current_stats_received.connect(func(_g, _r, _u): stats_received.emit())
	Steam.requestCurrentStats()

func _process(_delta: float) -> void:
	if _has_steam:
		Engine.get_singleton("Steam").run_callbacks()

# ── 成就 ──────────────────────────────────────────────────────

func unlock_achievement(api_name: String) -> void:
	if not _has_steam:
		print("[no-steam] would unlock achievement: ", api_name)
		achievement_unlocked.emit(api_name)
		return
	var Steam = Engine.get_singleton("Steam")
	Steam.setAchievement(api_name)
	Steam.storeStats()              # 必须 store 才会真正提交
	achievement_unlocked.emit(api_name)

func is_achievement_unlocked(api_name: String) -> bool:
	if not _has_steam:
		return false
	var d = Engine.get_singleton("Steam").getAchievement(api_name)
	return d.get("achieved", false)

func clear_achievement(api_name: String) -> void:
	if not _has_steam:
		print("[no-steam] would clear: ", api_name); return
	var Steam = Engine.get_singleton("Steam")
	Steam.clearAchievement(api_name)
	Steam.storeStats()

# ── 排行榜 ────────────────────────────────────────────────────

func upload_score(leaderboard: String, score: int) -> void:
	if not _has_steam:
		print("[no-steam] would upload %d to %s" % [score, leaderboard]); return
	var Steam = Engine.get_singleton("Steam")
	Steam.findLeaderboard(leaderboard)
	# 真实代码要 await Steam.leaderboard_find_result 拿到 handle,再 uploadLeaderboardScore

# ── 云存档 ────────────────────────────────────────────────────

func cloud_write(filename: String, data: PackedByteArray) -> bool:
	if not _has_steam:
		print("[no-steam] would cloud-write ", filename); return false
	return Engine.get_singleton("Steam").fileWrite(filename, data, data.size())

func cloud_read(filename: String) -> PackedByteArray:
	if not _has_steam:
		return PackedByteArray()
	var Steam = Engine.get_singleton("Steam")
	var size = Steam.getFileSize(filename)
	return Steam.fileRead(filename, size)
