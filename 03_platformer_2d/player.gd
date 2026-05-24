extends CharacterBody2D

# 一些常用平台跳跃手感参数
@export var move_speed: float = 320.0
@export var jump_velocity: float = -520.0        # 负数 = 向上(屏幕 y 轴朝下)
@export var gravity: float = 1400.0
@export var max_fall_speed: float = 900.0

# “土狼时间”:刚离开地面的若干毫秒内仍允许跳一次,手感更宽容
@export var coyote_time: float = 0.10
# 跳跃缓冲:落地前若干毫秒按了跳,落地立刻起跳
@export var jump_buffer_time: float = 0.10

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0

func _physics_process(delta: float) -> void:
	# 1) 横向:Input.get_axis 取 -1 / 0 / +1
	var x_input := Input.get_axis("move_left", "move_right")
	velocity.x = x_input * move_speed

	# 2) 纵向:重力持续下拉
	if not is_on_floor():
		velocity.y = min(velocity.y + gravity * delta, max_fall_speed)
		_coyote_timer -= delta
	else:
		_coyote_timer = coyote_time   # 在地面时随时刷新

	# 3) 跳跃缓冲:任何时候按下记录一下
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer -= delta

	# 4) 满足"地面/土狼" + "刚按/缓冲"就起跳
	var can_jump := is_on_floor() or _coyote_timer > 0.0
	if can_jump and _jump_buffer_timer > 0.0:
		velocity.y = jump_velocity
		_coyote_timer = 0.0
		_jump_buffer_timer = 0.0

	# 5) 让物理体真正动起来:它会做扫描、推墙、贴地
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
