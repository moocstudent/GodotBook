extends Node3D

@onready var cube: MeshInstance3D = %Cube
@onready var sphere: MeshInstance3D = %Sphere
@onready var post_rect: ColorRect = %PostRect
@onready var stats: Label = %StatsLabel

var _post_enabled := true
var _chroma_level := 1
var _rim_power := 2.5

func _process(delta: float) -> void:
	cube.rotate_y(delta * 0.8)
	cube.rotate_x(delta * 0.4)
	sphere.rotate_y(delta * -1.2)
	stats.text = "PostFX = %s · chroma=%d · rim_power=%.1f · FPS=%d" % [
		"ON" if _post_enabled else "OFF",
		_chroma_level,
		_rim_power,
		Engine.get_frames_per_second(),
	]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_T:
				_post_enabled = not _post_enabled
				post_rect.visible = _post_enabled
			KEY_1:
				_chroma_level = 1
				_set_chroma(0.003)
			KEY_2:
				_chroma_level = 2
				_set_chroma(0.008)
			KEY_3:
				_chroma_level = 3
				_set_chroma(0.016)
			KEY_Q:
				_rim_power = wrapf(_rim_power + 0.5, 0.5, 6.0)
				_set_rim(_rim_power)

func _set_chroma(v: float) -> void:
	(post_rect.material as ShaderMaterial).set_shader_parameter("chroma_amount", v)

func _set_rim(v: float) -> void:
	for m in [cube.material_override, sphere.material_override]:
		(m as ShaderMaterial).set_shader_parameter("rim_power", v)
