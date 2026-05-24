extends Control

@onready var lang_row: HBoxContainer = %LangRow
@onready var stats: Label = %Stats
@onready var start_btn: Button = %StartBtn

var locales: PackedStringArray = []
var _hours: int = 12

func _ready() -> void:
	locales = I18n.install("res://strings.csv")

	# 选语言按钮 —— 每个 locale 用它自己语种里的 LANG_NAME 显示
	# 例如 zh 的按钮显示 "中文"
	for loc in locales:
		var btn := Button.new()
		# 直接调 TranslationServer.translate_to,显示**那门语言下**的本地名
		btn.text = TranslationServer.translate_to(loc, "LANG_NAME")
		btn.custom_minimum_size = Vector2(120, 36)
		btn.pressed.connect(_on_pick_locale.bind(loc))
		lang_row.add_child(btn)

	# 默认 en
	_set_locale("en")

	start_btn.pressed.connect(func(): _hours += 1; _refresh_dynamic())

func _on_pick_locale(loc: String) -> void:
	_set_locale(loc)

func _set_locale(loc: String) -> void:
	TranslationServer.set_locale(loc)
	# 强制场景树重新评估翻译(所有 Control.text 是 key 的会自动用新 locale 渲染)
	propagate_notification(NOTIFICATION_TRANSLATION_CHANGED)
	_refresh_dynamic()

func _refresh_dynamic() -> void:
	# 动态拼接的文字不靠 auto_translate;手动 tr() + format
	stats.text = (
		tr("GREETING").format({"name": "Yolo"})
		+ "    "
		+ tr("WELCOME_BACK").format({"hours": _hours})
	)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
