extends Node2D

# @onready 在 _ready 之前给变量赋值,等价于把 $Title 写进 _ready 里
@onready var title: Label = $Title
@onready var hint: Label = $Hint

func _ready() -> void:
	# print 到 Godot 编辑器底部的 Output 面板
	var info := Engine.get_version_info()
	print("Engine: %s.%s.%s (%s)" % [info.major, info.minor, info.patch, info.status])
	title.text = "Hello, Godot!"
	hint.text = "按 ESC 退出 · 试着改 main.gd 里的文字"

func _unhandled_input(event: InputEvent) -> void:
	# ui_cancel 是内置 InputMap 动作,默认绑 Esc
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
