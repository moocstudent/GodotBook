extends Sprite2D

# @export 暴露到编辑器面板,运行时也可改
@export var speed: float = 300.0          # 像素/秒
@export var sprint_multiplier: float = 2.0

func _process(delta: float) -> void:
	# 两轴一次取出,自动归一化,无需手写 sqrt
	# 返回 Vector2,例如同时按 right+up 就是 (0.707, -0.707)
	var dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	var current_speed := speed
	if Input.is_key_pressed(KEY_SHIFT):
		current_speed *= sprint_multiplier

	# delta 让移动与帧率解耦:60fps 和 144fps 表现一致
	position += dir * current_speed * delta

	# 简单边界:不让 Sprite 跑出视口
	var vp := get_viewport_rect().size
	position.x = clamp(position.x, 0.0, vp.x)
	position.y = clamp(position.y, 0.0, vp.y)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
