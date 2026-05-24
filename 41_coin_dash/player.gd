extends CharacterBody2D

# 平台角色(整合 demo 03 的手感:重力 + 土狼时间 + 跳跃缓冲)。
signal jumped

@export var move_speed := 320.0
@export var jump_velocity := -560.0
@export var gravity := 1500.0
@export var coyote_time := 0.1
@export var jump_buffer := 0.1

var _coyote := 0.0
var _buffer := 0.0
var _frozen := false

func freeze() -> void:
	_frozen = true
	velocity = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if _frozen:
		return

	if not is_on_floor():
		velocity.y = min(velocity.y + gravity * delta, 1100.0)
		_coyote -= delta
	else:
		_coyote = coyote_time

	if Input.is_action_just_pressed("jump"):
		_buffer = jump_buffer
	else:
		_buffer -= delta

	if (_coyote > 0.0) and _buffer > 0.0:
		velocity.y = jump_velocity
		_coyote = 0.0
		_buffer = 0.0
		jumped.emit()

	velocity.x = Input.get_axis("move_left", "move_right") * move_speed
	move_and_slide()

	# 朝向
	var s := sign(velocity.x)
	if s != 0:
		$Body.scale.x = s
