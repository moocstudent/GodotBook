extends Control

# ╔══════════════════════════════════════════════════════════════╗
# ║  启动流程:                                                    ║
# ║   1) Splash 淡入(logo 出现)                                  ║
# ║   2) ResourceLoader.load_threaded_request 后台加载 game.tscn  ║
# ║   3) 每帧 poll 进度 -> 更新进度条                              ║
# ║   4) 加载完 + 最短展示时间到 -> 淡出 -> 切场景                  ║
# ║                                                              ║
# ║  关键 API:ResourceLoader.load_threaded_*(Godot 4 内置后台   ║
# ║  线程加载,不卡主线程)                                        ║
# ╚══════════════════════════════════════════════════════════════╝

const NEXT_SCENE := "res://game.tscn"
const MIN_SPLASH_TIME := 1.5     # 最短展示时间(防止"一闪而过")

@onready var logo: Label = %Logo
@onready var progress: ProgressBar = %ProgressBar
@onready var status: Label = %StatusLabel

var _elapsed := 0.0
var _load_done := false
var _switching := false

func _ready() -> void:
	# Logo 淡入
	logo.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(logo, "modulate:a", 1.0, 0.6)

	# 发起后台加载请求(立即返回,加载在别的线程跑)
	var err := ResourceLoader.load_threaded_request(NEXT_SCENE)
	if err != OK:
		status.text = "load request failed: %d" % err

func _process(delta: float) -> void:
	_elapsed += delta
	if _switching:
		return

	# poll 加载进度
	var progress_arr := []
	var st := ResourceLoader.load_threaded_get_status(NEXT_SCENE, progress_arr)
	var pct: float = progress_arr[0] if progress_arr.size() > 0 else 0.0

	match st:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			progress.value = pct
			status.text = "loading assets... %d%%" % int(pct * 100)
		ResourceLoader.THREAD_LOAD_LOADED:
			progress.value = 1.0
			status.text = "ready"
			_load_done = true
		ResourceLoader.THREAD_LOAD_FAILED:
			status.text = "LOAD FAILED"
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			status.text = "INVALID RESOURCE PATH"

	# 加载完 + 最短时间到 -> 切场景
	if _load_done and _elapsed >= MIN_SPLASH_TIME:
		_go_to_game()

func _go_to_game() -> void:
	_switching = true
	status.text = "entering..."
	# 淡出
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.4)
	await t.finished

	# 取出已加载好的 PackedScene 并切换(瞬间,因为已经加载完)
	var scene: PackedScene = ResourceLoader.load_threaded_get(NEXT_SCENE)
	get_tree().change_scene_to_packed(scene)
