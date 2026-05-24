extends Control

const TYPE_SPEED := 40.0    # 每秒显示字符数

@onready var top_bar: Label = %TopBar
@onready var speaker: Label = %Speaker
@onready var body: RichTextLabel = %Body
@onready var choices_box: VBoxContainer = %Choices

var dp := DialoguePlayer.new()
var _full_text := ""
var _shown_chars := 0.0
var _typing := false

func _ready() -> void:
	if not dp.load_from_file("res://dialogue.json"):
		body.text = "无法加载 dialogue.json"
		return
	dp.start()
	_present_node()

func _present_node() -> void:
	var node := dp.current_node()
	speaker.text = node.get("speaker", "")
	_full_text = node.get("text", "")
	_shown_chars = 0.0
	_typing = true
	body.text = ""
	_clear_choices()
	_update_top()

func _process(delta: float) -> void:
	if _typing:
		_shown_chars += TYPE_SPEED * delta
		var n := int(_shown_chars)
		if n >= _full_text.length():
			n = _full_text.length()
			_typing = false
			_show_choices()
		body.text = _full_text.substr(0, n)

func _show_choices() -> void:
	_clear_choices()
	if dp.is_finished():
		var done := Button.new()
		done.text = "[ 对话结束 — 按 ESC 退出 / 点这重来 ]"
		done.pressed.connect(func(): dp.start(); _present_node())
		choices_box.add_child(done)
		return

	var choices := dp.available_choices()
	for i in choices.size():
		var c: Dictionary = choices[i]
		var btn := Button.new()
		var enabled := dp.choice_enabled(c)
		btn.text = ("%d. " % (i + 1)) + c.get("text", "")
		if not enabled and c.has("require_gold"):
			btn.text += "  (需要 %d 金币)" % c["require_gold"]
			btn.disabled = true
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var idx := i
		btn.pressed.connect(func(): _pick(idx))
		choices_box.add_child(btn)

func _pick(index: int) -> void:
	dp.pick(index)
	_present_node()

func _clear_choices() -> void:
	for c in choices_box.get_children():
		c.queue_free()

func _update_top() -> void:
	top_bar.text = "金币: %d   状态: %s   ·   空格/回车=跳过打字   1-9=选项" % [
		dp.gold, str(dp.state)
	]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

	# 空格/回车:跳过打字机
	if event.is_action_pressed("ui_accept"):
		if _typing:
			_typing = false
			body.text = _full_text
			_show_choices()

	# 数字键选选项
	if event is InputEventKey and event.pressed and not _typing:
		var num := event.physical_keycode - KEY_1
		if num >= 0 and num < 9:
			_pick(num)
