extends Node3D

@onready var mesh_holder: Node3D = %MeshHolder
@onready var cam_pivot: Node3D = %CamPivot
@onready var camera: Camera3D = %CamPivot/Camera
@onready var stats: Label = %StatsLabel

var _current: MeshInstance3D
var _cam_distance := 5.5
var _dragging := false

func _ready() -> void:
	_show_mesh("cube")

func _show_mesh(kind: String) -> void:
	if _current:
		_current.queue_free()

	var mesh: ArrayMesh
	match kind:
		"cube":    mesh = MeshFactory.make_cube(2.0)
		"sphere":  mesh = MeshFactory.make_sphere(1.4, 24, 32)
		"planet":  mesh = MeshFactory.make_sphere(1.4, 48, 64, 0.35)
		"terrain": mesh = MeshFactory.make_terrain(64, 6.0, 1.2)

	_current = MeshInstance3D.new()
	_current.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.6, 0.75)
	mat.roughness = 0.6
	if kind == "planet" or kind == "terrain":
		# 按高度上色:用顶点 + 简单渐变(这里用单色,练习里可换 vertex color)
		mat.albedo_color = Color(0.45, 0.7, 0.5)
	_current.material_override = mat
	mesh_holder.add_child(_current)

	var v := mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	stats.text = "mesh: %s · vertices: %d · 拖动旋转 · 滚轮缩放" % [kind, v]

func _process(delta: float) -> void:
	# 缓慢自转
	mesh_holder.rotate_y(delta * 0.3)
	camera.position.z = lerp(camera.position.z, _cam_distance, 0.1)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1: _show_mesh("cube")
			KEY_2: _show_mesh("sphere")
			KEY_3: _show_mesh("planet")
			KEY_4: _show_mesh("terrain")

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_distance = max(2.5, _cam_distance - 0.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_distance = min(14.0, _cam_distance + 0.5)

	if event is InputEventMouseMotion and _dragging:
		cam_pivot.rotate_y(-event.relative.x * 0.01)
		cam_pivot.rotate_object_local(Vector3.RIGHT, -event.relative.y * 0.01)
