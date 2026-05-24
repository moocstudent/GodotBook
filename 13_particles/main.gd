extends Node2D

@onready var cursor: Node2D = %Cursor
@onready var stats: Label = %StatsLabel
@onready var explosions: Node2D = %Explosions
@onready var boom_template: CPUParticles2D = %BoomTemplate

func _process(_delta: float) -> void:
	# 让 Cursor 跟鼠标 -> 子节点 Trail 自动跟着
	cursor.global_position = get_global_mouse_position()
	stats.text = "active explosions: %d · cursor: %s" % [
		explosions.get_child_count(),
		cursor.global_position.round()
	]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_spawn_cpu_boom(event.position)
			MOUSE_BUTTON_RIGHT:
				_spawn_gpu_boom(event.position)
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_R:
		for c in explosions.get_children():
			c.queue_free()

# ── CPU 爆炸:复制模板节点,启动一次性发射 ────────────────────

func _spawn_cpu_boom(pos: Vector2) -> void:
	var boom: CPUParticles2D = boom_template.duplicate()
	boom.position = pos
	boom.emitting = true
	explosions.add_child(boom)
	# 寿命 + 一点缓冲后自销毁
	get_tree().create_timer(boom.lifetime + 0.2).timeout.connect(boom.queue_free)

# ── GPU 爆炸:用 GPUParticles2D + 程序化生成 ProcessMaterial ──

func _spawn_gpu_boom(pos: Vector2) -> void:
	var p := GPUParticles2D.new()
	p.position = pos
	p.amount = 220
	p.lifetime = 1.2
	p.one_shot = true
	p.explosiveness = 0.98
	p.randomness = 0.6
	p.emitting = true

	# GPU 版需要 ParticleProcessMaterial,所有运动规律靠它定义
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 4.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 200.0
	mat.initial_velocity_max = 500.0
	mat.gravity = Vector3(0, 240, 0)
	mat.scale_min = 3.0
	mat.scale_max = 7.0

	# 颜色渐变 → ParticleProcessMaterial.color_ramp 要 GradientTexture1D
	var grad := Gradient.new()
	grad.set_color(0, Color(0.6, 0.85, 1.0, 1.0))    # 蓝
	grad.set_color(1, Color(1.0, 0.6, 0.2, 0.0))     # 橙→透明
	grad.add_point(0.4, Color(1.0, 1.0, 1.0, 1.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex

	p.process_material = mat
	# GPU 粒子默认需要 texture,空就用 1x1 白色
	p.texture = _white_pixel()

	explosions.add_child(p)
	get_tree().create_timer(p.lifetime + 0.4).timeout.connect(p.queue_free)

# 1x1 白点 → 当作粒子的"形状"
func _white_pixel() -> Texture2D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(img)
