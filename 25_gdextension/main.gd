extends Node2D

@onready var status: Label = %StatusLabel
@onready var bobbers: Node2D = %Bobbers

func _ready() -> void:
	# 优雅降级:GDExtension 还没编译时,显示提示而不是崩溃
	if not ClassDB.class_exists("SineBobber"):
		status.text = ("[WARN] SineBobber 类没有注册 —— GDExtension 还没编译。\n"
			+ "运行 `& .\\build.ps1` 编译 C++ 部分,然后重启 Godot。\n"
			+ "(下面会用 GDScript 模拟一个版本,体感一样)")
		_spawn_gdscript_fallback()
		return

	status.text = "[OK] SineBobber 类已加载(来自 C++ GDExtension)。"
	_spawn_cpp_bobbers()

func _spawn_cpp_bobbers() -> void:
	for i in 8:
		# 直接由 ClassDB 实例化 C++ 类
		var b: Node2D = ClassDB.instantiate("SineBobber")
		b.set("amplitude", 60.0)
		b.set("frequency", 0.8 + i * 0.05)
		b.set("phase", i * 0.4)
		b.position = Vector2(-280 + i * 80, 0)
		bobbers.add_child(b)
		_attach_visual(b, Color.from_hsv(i / 8.0, 0.7, 1.0))

func _spawn_gdscript_fallback() -> void:
	for i in 8:
		var b := Node2D.new()
		var origin := Vector2(-280 + i * 80, 0)
		b.position = origin
		bobbers.add_child(b)
		_attach_visual(b, Color.from_hsv(i / 8.0, 0.4, 0.8))
		# 用 Tween 模拟正弦移动
		var t := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var dur := 1.0 + i * 0.06
		t.tween_property(b, "position:y", -60.0, dur)
		t.tween_property(b, "position:y", 60.0, dur)

func _attach_visual(parent: Node2D, color: Color) -> void:
	var rect := ColorRect.new()
	rect.offset_left = -20.0
	rect.offset_top = -20.0
	rect.offset_right = 20.0
	rect.offset_bottom = 20.0
	rect.color = color
	parent.add_child(rect)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
