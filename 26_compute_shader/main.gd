extends Node2D

# ╔══════════════════════════════════════════════════════════════╗
# ║  RenderingDevice 计算着色器:在 GPU 上跑 boids 群体模拟         ║
# ║                                                              ║
# ║  流程:                                                       ║
# ║   1) 创建本地 RenderingDevice                                 ║
# ║   2) 编译 .glsl -> shader -> pipeline                        ║
# ║   3) 把 boid 数据放进 SSBO(storage buffer)                  ║
# ║   4) 每帧 dispatch,GPU 并行更新所有 boid                     ║
# ║   5) 读回 buffer,在屏幕上画                                   ║
# ║                                                              ║
# ║  注意:读回(buffer_get_data)是同步的,会拖慢 —— 真实游戏会     ║
# ║  让结果直接喂给渲染 shader,不回 CPU。本 demo 为了可视化才读回。  ║
# ╚══════════════════════════════════════════════════════════════╝

const FLOATS_PER_BOID := 4         # pos.xy, vel.xy
const PARAM_FLOATS := 12

var boid_count := 512
var bounds := Vector2(1152, 648)

var rd: RenderingDevice
var shader: RID
var pipeline: RID
var boid_buffer: RID
var param_buffer: RID
var uniform_set: RID

var boid_data: PackedFloat32Array
var use_gpu := true

@onready var stats: Label = %StatsLabel
@onready var renderer: Node2D = %BoidRenderer

func _ready() -> void:
	_init_boids()
	_setup_compute()
	renderer.draw.connect(_draw_boids)

func _init_boids() -> void:
	boid_data = PackedFloat32Array()
	boid_data.resize(boid_count * FLOATS_PER_BOID)
	for i in boid_count:
		boid_data[i * 4 + 0] = randf() * bounds.x
		boid_data[i * 4 + 1] = randf() * bounds.y
		var angle := randf() * TAU
		boid_data[i * 4 + 2] = cos(angle) * 80.0
		boid_data[i * 4 + 3] = sin(angle) * 80.0

func _setup_compute() -> void:
	# 本地 RenderingDevice(与主渲染分开,避免干扰)
	rd = RenderingServer.create_local_rendering_device()
	if rd == null:
		stats.text = "[ERR] 无法创建 RenderingDevice(可能是 gl_compatibility 渲染器,本 demo 需要 Forward+/Mobile)"
		use_gpu = false
		return

	var shader_file: RDShaderFile = load("res://boids.glsl")
	var spirv := shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(spirv)
	pipeline = rd.compute_pipeline_create(shader)

	_upload_buffers()

func _upload_buffers() -> void:
	var bytes := boid_data.to_byte_array()
	boid_buffer = rd.storage_buffer_create(bytes.size(), bytes)

	var params := _make_params(0.016)
	var pbytes := params.to_byte_array()
	param_buffer = rd.storage_buffer_create(pbytes.size(), pbytes)

	var u0 := RDUniform.new()
	u0.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u0.binding = 0
	u0.add_id(boid_buffer)

	var u1 := RDUniform.new()
	u1.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u1.binding = 1
	u1.add_id(param_buffer)

	uniform_set = rd.uniform_set_create([u0, u1], shader, 0)

func _make_params(delta: float) -> PackedFloat32Array:
	var p := PackedFloat32Array()
	p.resize(PARAM_FLOATS)
	p[0] = delta
	p[1] = float(boid_count)
	p[2] = bounds.x
	p[3] = bounds.y
	p[4] = 90.0      # sep_weight
	p[5] = 1.0       # align_weight
	p[6] = 1.0       # cohesion_weight
	p[7] = 160.0     # max_speed
	p[8] = 40.0      # neighbor_radius
	return p

func _process(delta: float) -> void:
	if use_gpu and rd != null:
		_step_gpu(delta)
	else:
		_step_cpu(delta)
	renderer.queue_redraw()
	stats.text = "%s · boids=%d · FPS=%d" % [
		"GPU compute" if (use_gpu and rd != null) else "CPU fallback",
		boid_count, Engine.get_frames_per_second()
	]

func _step_gpu(delta: float) -> void:
	# 更新 param buffer(delta 每帧变)
	rd.buffer_update(param_buffer, 0, PARAM_FLOATS * 4, _make_params(delta).to_byte_array())

	# 录制 + 提交 compute pass
	var groups := int(ceil(boid_count / 64.0))
	var cl := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(cl, pipeline)
	rd.compute_list_bind_uniform_set(cl, uniform_set, 0)
	rd.compute_list_dispatch(cl, groups, 1, 1)
	rd.compute_list_end()
	rd.submit()
	rd.sync()    # 等 GPU 完成(同步,慢;真实项目用 fence/double-buffer)

	# 读回结果用于绘制
	var out := rd.buffer_get_data(boid_buffer)
	boid_data = out.to_float32_array()

func _step_cpu(delta: float) -> void:
	# CPU 版(仅作对比,O(n^2),很慢)
	var new_data := boid_data.duplicate()
	for i in boid_count:
		var pos := Vector2(boid_data[i*4], boid_data[i*4+1])
		var vel := Vector2(boid_data[i*4+2], boid_data[i*4+3])
		var sep := Vector2.ZERO
		var ali := Vector2.ZERO
		var coh := Vector2.ZERO
		var cnt := 0
		for j in boid_count:
			if j == i: continue
			var op := Vector2(boid_data[j*4], boid_data[j*4+1])
			var d := pos.distance_to(op)
			if d > 0 and d < 40.0:
				sep += (pos - op).normalized() / d
				ali += Vector2(boid_data[j*4+2], boid_data[j*4+3])
				coh += op
				cnt += 1
		if cnt > 0:
			ali /= cnt
			coh = coh / cnt - pos
			vel += sep * 90.0 + ali * 0.05 + coh * 0.02
		var sp := vel.length()
		if sp > 160.0: vel = vel / sp * 160.0
		if sp < 20.0: vel = (vel.normalized() if sp > 0 else Vector2.RIGHT) * 20.0
		pos += vel * delta
		pos.x = wrapf(pos.x, 0, bounds.x)
		pos.y = wrapf(pos.y, 0, bounds.y)
		new_data[i*4] = pos.x; new_data[i*4+1] = pos.y
		new_data[i*4+2] = vel.x; new_data[i*4+3] = vel.y
	boid_data = new_data

func _draw_boids() -> void:
	for i in boid_count:
		var pos := Vector2(boid_data[i*4], boid_data[i*4+1])
		var vel := Vector2(boid_data[i*4+2], boid_data[i*4+3])
		var dir := vel.normalized()
		# 画一个小三角形指向速度方向
		var p1 := pos + dir * 7.0
		var p2 := pos + dir.rotated(2.5) * 4.0
		var p3 := pos + dir.rotated(-2.5) * 4.0
		var hue := fmod(float(i) / boid_count + 0.55, 1.0)
		renderer.draw_polygon(
			PackedVector2Array([p1, p2, p3]),
			PackedColorArray([Color.from_hsv(hue, 0.6, 1.0)])
		)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_EQUAL, KEY_KP_ADD:
				_resize(boid_count + 256)
			KEY_MINUS, KEY_KP_SUBTRACT:
				_resize(max(64, boid_count - 256))
			KEY_C:
				use_gpu = not use_gpu

func _resize(n: int) -> void:
	boid_count = n
	_cleanup_gpu()
	_init_boids()
	if rd != null:
		_upload_buffers()

func _cleanup_gpu() -> void:
	if rd == null: return
	if uniform_set.is_valid(): rd.free_rid(uniform_set)
	if boid_buffer.is_valid(): rd.free_rid(boid_buffer)
	if param_buffer.is_valid(): rd.free_rid(param_buffer)

func _exit_tree() -> void:
	if rd == null: return
	_cleanup_gpu()
	if pipeline.is_valid(): rd.free_rid(pipeline)
	if shader.is_valid(): rd.free_rid(shader)
	rd.free()
