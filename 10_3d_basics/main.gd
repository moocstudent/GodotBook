extends Node3D

@onready var hero: MeshInstance3D = %Hero
@onready var pivot: Node3D = %CamPivot
@onready var camera: Camera3D = %Camera
@onready var spawned: Node3D = %Spawned
@onready var stats: Label = %StatsLabel

@export var orbit_speed: float = 1.4         # 弧度/秒
@export var zoom_speed: float = 4.0
@export var min_distance: float = 3.0
@export var max_distance: float = 18.0

var _camera_distance: float = 8.0

func _ready() -> void:
	# 初始拉到默认距离
	_apply_camera_distance(_camera_distance)

func _process(delta: float) -> void:
	# Hero 持续自转 -> Y 轴(立方"立"在 Y+ 方向)
	hero.rotate_y(delta * 1.2)

	# 公转:绕 pivot 的 Y 轴转
	var orbit := Input.get_axis("orbit_left", "orbit_right")
	pivot.rotate_y(orbit * orbit_speed * delta)

	# 推拉镜头
	var zoom_input := Input.get_axis("zoom_in", "zoom_out")  # 注意 in -> -1, out -> +1
	if zoom_input != 0.0:
		_camera_distance = clamp(
			_camera_distance + zoom_input * zoom_speed * delta,
			min_distance, max_distance
		)
		_apply_camera_distance(_camera_distance)

	stats.text = "Spawned cubes: %d · cam distance: %.1f · FPS: %d" % [
		spawned.get_child_count(), _camera_distance, Engine.get_frames_per_second()
	]

func _apply_camera_distance(d: float) -> void:
	# Camera 在 CamPivot 的本地坐标里,简单设 Z(距离)+ Y(俯角)
	# 俯角 ~30°,通过 y/z 比例呈现
	camera.position = Vector3(0, d * 0.55, d)
	camera.look_at(pivot.global_position, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	elif event.is_action_pressed("spawn"):
		_spawn_random_cube()

# ── 程序化生成一个 cube,带随机颜色 + 落点 ─────────────────────

func _spawn_random_cube() -> void:
	var cube := MeshInstance3D.new()
	cube.mesh = BoxMesh.new()
	(cube.mesh as BoxMesh).size = Vector3(
		randf_range(0.6, 1.4),
		randf_range(0.6, 1.4),
		randf_range(0.6, 1.4)
	)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.from_hsv(randf(), 0.7, 0.95)
	mat.roughness = 0.5
	cube.material_override = mat

	var radius := randf_range(2.5, 7.5)
	var angle := randf() * TAU
	cube.position = Vector3(cos(angle) * radius, 0.5, sin(angle) * radius)
	cube.rotation = Vector3(0, randf() * TAU, 0)
	spawned.add_child(cube)

	# 简单 Tween 落下
	var fall_to_y := cube.position.y
	cube.position.y = fall_to_y + 6.0
	var t := create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t.tween_property(cube, "position:y", fall_to_y, 0.7)
