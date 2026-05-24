extends Control

@onready var steam: Node = %Steam_
@onready var status: Label = %StatusLabel
@onready var unlock_btn: Button = %UnlockBtn
@onready var score_btn: Button = %ScoreBtn
@onready var cloud_btn: Button = %CloudBtn
@onready var log_view: TextEdit = %Log

func _ready() -> void:
	await get_tree().process_frame   # 等 steam wrapper _ready
	status.text = "Steam user: %s (id=%d)\n%s" % [
		steam.steam_name, steam.steam_id,
		"GodotSteam 已加载" if Engine.has_singleton("Steam") else "GodotSteam 未安装 → 全部 no-op(开发模式)"
	]

	steam.achievement_unlocked.connect(func(n): _log("achievement unlocked: " + n))

	unlock_btn.pressed.connect(func():
		steam.unlock_achievement("ACH_FIRST_WIN")
		_log("called unlock_achievement"))

	score_btn.pressed.connect(func():
		var s := randi() % 100000
		steam.upload_score("HIGHSCORE", s)
		_log("called upload_score: %d" % s))

	cloud_btn.pressed.connect(func():
		var ok := steam.cloud_write("save.dat", "hello steam cloud".to_utf8_buffer())
		_log("cloud_write returned: %s" % ok))

func _log(line: String) -> void:
	log_view.text += line + "\n"
	log_view.scroll_vertical = 9999

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
