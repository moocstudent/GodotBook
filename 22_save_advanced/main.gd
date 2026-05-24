extends Control

@onready var name_edit: LineEdit = %NameEdit
@onready var score_label: Label = %ScoreLabel
@onready var level_label: Label = %LevelLabel
@onready var score_plus: Button = %ScorePlus
@onready var score_minus: Button = %ScoreMinus
@onready var level_up: Button = %LevelUp
@onready var encrypt_check: CheckBox = %EncryptCheck
@onready var cloud_url: LineEdit = %CloudUrlEdit
@onready var slots_list: VBoxContainer = %SlotsList
@onready var path_label: Label = %PathLabel
@onready var log_view: TextEdit = %Log

var data: Dictionary = SaveSystem.default_data()
var cloud: CloudSync

# 用一个数组保存每个 slot 行的 children 引用,方便刷新
var _slot_rows: Array = []

func _ready() -> void:
	cloud = CloudSync.new()
	add_child(cloud)
	cloud.sync_done.connect(_on_sync_done)

	score_plus.pressed.connect(func(): data.score += 10; _refresh_editor())
	score_minus.pressed.connect(func(): data.score -= 10; _refresh_editor())
	level_up.pressed.connect(func(): data.level += 1; _refresh_editor())
	name_edit.text_changed.connect(func(t): data.player_name = t)
	cloud_url.text_changed.connect(func(t): cloud.server_base = t)

	cloud.server_base = cloud_url.text

	_build_slot_rows()
	_refresh_editor()
	_refresh_slot_rows()
	path_label.text = "存档目录: %s" % ProjectSettings.globalize_path(SaveSystem.SAVE_DIR)
	_log("Ready. 默认从 slot 0 加载.")
	_on_load(0)

func _refresh_editor() -> void:
	name_edit.text = data.get("player_name", "Player")
	score_label.text = "score: %d" % data.get("score", 0)
	level_label.text = "Lv: %d" % data.get("level", 1)

# ── Slot UI 构造 + 刷新 ───────────────────────────────────────

func _build_slot_rows() -> void:
	for i in SaveSystem.SLOT_COUNT:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		slots_list.add_child(row)

		var idx_label := Label.new()
		idx_label.text = "Slot %d" % i
		idx_label.custom_minimum_size = Vector2(80, 0)
		row.add_child(idx_label)

		var summary := Label.new()
		summary.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(summary)

		var save_btn := Button.new(); save_btn.text = "Save"
		save_btn.pressed.connect(_on_save.bind(i))
		row.add_child(save_btn)

		var load_btn := Button.new(); load_btn.text = "Load"
		load_btn.pressed.connect(_on_load.bind(i))
		row.add_child(load_btn)

		var del_btn := Button.new(); del_btn.text = "Delete"
		del_btn.pressed.connect(_on_delete.bind(i))
		row.add_child(del_btn)

		var push_btn := Button.new(); push_btn.text = "↑Cloud"
		push_btn.pressed.connect(_on_push.bind(i))
		row.add_child(push_btn)

		var pull_btn := Button.new(); pull_btn.text = "↓Cloud"
		pull_btn.pressed.connect(_on_pull.bind(i))
		row.add_child(pull_btn)

		_slot_rows.append({"summary": summary})

func _refresh_slot_rows() -> void:
	for i in SaveSystem.SLOT_COUNT:
		_slot_rows[i].summary.text = SaveSystem.slot_summary(i)

# ── 按钮 handlers ─────────────────────────────────────────────

func _on_save(slot: int) -> void:
	var err := SaveSystem.save(slot, data, encrypt_check.button_pressed)
	if err == OK:
		_log("[save] slot %d %s OK" % [slot, "(encrypted)" if encrypt_check.button_pressed else "(plain)"])
	else:
		_log("[save] slot %d FAILED err=%d" % [slot, err])
	_refresh_slot_rows()

func _on_load(slot: int) -> void:
	data = SaveSystem.load_slot(slot)
	_refresh_editor()
	_log("[load] slot %d ver=%d score=%d level=%d" % [slot, data.version, data.score, data.level])

func _on_delete(slot: int) -> void:
	SaveSystem.delete_slot(slot)
	_log("[del] slot %d wiped" % slot)
	_refresh_slot_rows()

func _on_push(slot: int) -> void:
	# 先确保本地有最新版
	SaveSystem.save(slot, data, encrypt_check.button_pressed)
	cloud.push_slot(slot, data)
	_log("[cloud↑] pushing slot %d ..." % slot)

func _on_pull(slot: int) -> void:
	cloud.pull_slot(slot)
	_log("[cloud↓] pulling slot %d ..." % slot)

func _on_sync_done(success: bool, msg: String) -> void:
	_log("[cloud] %s · %s" % ["OK" if success else "FAIL", msg])
	_refresh_slot_rows()

func _log(line: String) -> void:
	var ts := Time.get_time_string_from_system()
	log_view.text += "[%s] %s\n" % [ts, line]
	log_view.scroll_vertical = 9999

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
