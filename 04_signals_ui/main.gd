extends Control

# 自定义信号:外部可订阅,实现"业务事件"解耦
signal count_changed(new_value: int)
signal milestone_reached(value: int)

# %X 语法:取项目中"Unique Name in Owner"的节点,比 $A/B/C 更稳健
@onready var count_label: Label = %CountLabel
@onready var status_label: Label = %StatusLabel
@onready var plus_button: Button = %PlusButton
@onready var minus_button: Button = %MinusButton
@onready var reset_button: Button = %ResetButton

var count: int = 0:
	set(value):
		count = value
		count_label.text = str(count)
		count_changed.emit(count)
		if count != 0 and count % 10 == 0:
			milestone_reached.emit(count)

func _ready() -> void:
	# 方式 1:代码连接信号(推荐,可被静态检查到)
	plus_button.pressed.connect(_on_plus_pressed)
	minus_button.pressed.connect(_on_minus_pressed)
	reset_button.pressed.connect(_on_reset_pressed)

	# 自定义信号也可订阅
	count_changed.connect(_on_count_changed)
	milestone_reached.connect(_on_milestone)

	# 初始化 UI
	count = 0
	status_label.text = "Tip: 连到 10 的倍数会触发 milestone"

func _on_plus_pressed() -> void:
	count += 1

func _on_minus_pressed() -> void:
	count -= 1

func _on_reset_pressed() -> void:
	count = 0

func _on_count_changed(value: int) -> void:
	# 这里可以做依赖 count 的副作用,比如保存、刷新别处 UI
	print("count -> ", value)

func _on_milestone(value: int) -> void:
	status_label.text = "里程碑达成: %d!" % value

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
