extends Control

@onready var name_edit: LineEdit = %NameEdit
@onready var score_label: Label = %ScoreLabel
@onready var level_label: Label = %LevelLabel
@onready var plus_btn: Button = %PlusButton
@onready var minus_btn: Button = %MinusButton
@onready var level_up_btn: Button = %LevelUpButton
@onready var save_btn: Button = %SaveButton
@onready var load_btn: Button = %LoadButton
@onready var delete_btn: Button = %DeleteButton
@onready var status: Label = %StatusLabel
@onready var path_label: Label = %PathLabel

var data: Dictionary = SaveManager.default_data()

func _ready() -> void:
	plus_btn.pressed.connect(func(): data.score += 10; _refresh())
	minus_btn.pressed.connect(func(): data.score -= 10; _refresh())
	level_up_btn.pressed.connect(func(): data.level += 1; _refresh())

	save_btn.pressed.connect(_on_save)
	load_btn.pressed.connect(_on_load)
	delete_btn.pressed.connect(_on_delete)

	name_edit.text_changed.connect(func(t): data.player_name = t)

	# 启动即读档(常见做法:自动加载上次进度)
	_on_load()
	path_label.text = "存档绝对路径: %s" % SaveManager.save_file_path()

func _refresh() -> void:
	score_label.text = "Score: %d" % data.score
	level_label.text = "Level: %d" % data.level
	name_edit.text = str(data.player_name)

func _on_save() -> void:
	var err := SaveManager.save(data)
	if err == OK:
		status.text = "[Save] 写入成功 (version=%d)" % data.version
	else:
		status.text = "[Save] 失败,error code=%d" % err

func _on_load() -> void:
	data = SaveManager.load_data()
	_refresh()
	status.text = "[Load] 已加载存档 (version=%d, score=%d, level=%d)" % [
		data.version, data.score, data.level
	]

func _on_delete() -> void:
	var err := SaveManager.delete()
	if err == OK:
		status.text = "[Delete] 存档已删除,重置为默认"
		data = SaveManager.default_data()
		_refresh()
	else:
		status.text = "[Delete] 失败,error code=%d" % err

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
