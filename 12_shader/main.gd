extends Node2D

# 这个 demo 主要展示 "shader 跑起来"。
# 这里加点交互:数字键 1-4 调 glow 脉冲速度,让你看到 shader uniform 怎么从 GDScript 改。
@onready var glow_rect: ColorRect = %GlowRect
@onready var status: Label = %StatusLabel

func _ready() -> void:
	_set_pulse(1.5)

func _set_pulse(v: float) -> void:
	# ShaderMaterial 的 uniform 在运行时改 -> set_shader_parameter
	var mat: ShaderMaterial = glow_rect.material
	mat.set_shader_parameter("pulse_speed", v)
	status.text = "glow.pulse_speed = %.1f" % v

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1: _set_pulse(0.5)
			KEY_2: _set_pulse(1.5)
			KEY_3: _set_pulse(3.0)
			KEY_4: _set_pulse(5.0)
