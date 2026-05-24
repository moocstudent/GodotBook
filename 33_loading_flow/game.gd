extends Control

@onready var info: Label = %Info
@onready var reload_btn: Button = %ReloadBtn

func _ready() -> void:
	# 进场淡入
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)

	info.text = "已通过后台线程加载并切入。\n这个场景在 splash 显示期间就加载好了,切换是瞬间的。"
	reload_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://splash.tscn")
	)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
