extends CharacterBody3D

@export var move_speed: float = 6.0
@export var jump_velocity: float = 5.5
@export var gravity: float = 20.0
@export var mouse_sensitivity: float = 0.0022

@onready var cam_pivot: Node3D = $CamPivot          # 控制俯仰
@onready var camera: Camera3D = $CamPivot/Camera

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	# 鼠标移动 → yaw(身体)+ pitch(相机)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		cam_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		# 夹住 pitch,不让头顶倒过来
		cam_pivot.rotation.x = clamp(cam_pivot.rotation.x, -1.4, 1.4)

	# ESC:第一次按 = 释放鼠标,第二次按 = 退出
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			get_tree().quit()

	# 左键(或任何鼠标按)重新抓回鼠标
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	# 重力
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 跳跃
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# 把"前后左右"输入转成相对身体朝向的世界方向
	# transform.basis 的列向量 = 当前角色的 X/Y/Z 轴
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed

	move_and_slide()
