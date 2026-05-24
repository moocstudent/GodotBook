extends Node2D

# ╔══════════════════════════════════════════════════════════════╗
# ║  简化 SPH(Smoothed Particle Hydrodynamics)2D 流体             ║
# ║                                                              ║
# ║  每帧三步:                                                   ║
# ║   1) 计算每个粒子的密度(看周围多挤)                          ║
# ║   2) 由密度算压力,压力梯度产生力(挤 → 推开)+ 粘性力          ║
# ║   3) 积分速度/位置 + 边界反弹                                  ║
# ║                                                              ║
# ║  邻居查找用空间哈希网格(cell size = 光滑半径 h)把 O(n²)      ║
# ║  降到接近 O(n)。                                              ║
# ╚══════════════════════════════════════════════════════════════╝

const H := 28.0                # 光滑半径(粒子作用范围)
const H2 := H * H
const REST_DENSITY := 2.5
const STIFFNESS := 280.0       # 压力系数(越大越"硬"越不可压)
const VISCOSITY := 26.0
const GRAVITY := Vector2(0, 520.0)
const MASS := 1.0
const BOUNDS := Vector2(1152, 648)
const DAMPING := 0.5           # 边界反弹能量损失

var count := 420
var pos: PackedVector2Array
var vel: PackedVector2Array
var dens: PackedFloat32Array
var pres: PackedFloat32Array

# 空间哈希:cell -> Array[int]
var grid := {}
var cell_size := H

@onready var renderer: Node2D = %FluidRenderer
@onready var stats: Label = %StatsLabel

func _ready() -> void:
	_reset()
	renderer.draw.connect(_draw_fluid)

func _reset() -> void:
	pos = PackedVector2Array(); pos.resize(count)
	vel = PackedVector2Array(); vel.resize(count)
	dens = PackedFloat32Array(); dens.resize(count)
	pres = PackedFloat32Array(); pres.resize(count)
	# 初始在左上方堆一块
	var cols := 21
	for i in count:
		var x := 120.0 + (i % cols) * (H * 0.55)
		var y := 90.0 + (i / cols) * (H * 0.55)
		pos[i] = Vector2(x, y)
		vel[i] = Vector2.ZERO

func _physics_process(delta: float) -> void:
	# 固定步长更稳;clamp 防止卡顿时爆炸
	var dt: float = min(delta, 1.0 / 60.0)
	_build_grid()
	_compute_density_pressure()
	_compute_forces_and_integrate(dt)
	_handle_mouse(dt)
	renderer.queue_redraw()
	stats.text = "SPH · particles=%d · FPS=%d · 左键灌水 右键排斥" % [count, Engine.get_frames_per_second()]

# ── 空间哈希 ──────────────────────────────────────────────────

func _cell_key(p: Vector2) -> Vector2i:
	return Vector2i(int(p.x / cell_size), int(p.y / cell_size))

func _build_grid() -> void:
	grid.clear()
	for i in count:
		var key := _cell_key(pos[i])
		if not grid.has(key):
			grid[key] = []
		grid[key].append(i)

func _neighbors(p: Vector2) -> Array:
	var out: Array = []
	var c := _cell_key(p)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var key := c + Vector2i(dx, dy)
			if grid.has(key):
				out.append_array(grid[key])
	return out

# ── SPH 核心 ──────────────────────────────────────────────────

func _compute_density_pressure() -> void:
	# Poly6 核(2D 简化系数)
	for i in count:
		var rho := 0.0
		for j in _neighbors(pos[i]):
			var r2: float = pos[i].distance_squared_to(pos[j])
			if r2 < H2:
				var x := H2 - r2
				rho += MASS * x * x * x
		dens[i] = max(rho * 0.000004, REST_DENSITY)
		pres[i] = STIFFNESS * (dens[i] - REST_DENSITY)

func _compute_forces_and_integrate(dt: float) -> void:
	for i in count:
		var f_press := Vector2.ZERO
		var f_visc := Vector2.ZERO
		for j in _neighbors(pos[i]):
			if i == j: continue
			var diff: Vector2 = pos[i] - pos[j]
			var dist := diff.length()
			if dist < H and dist > 0.0001:
				var dir := diff / dist
				var x := H - dist
				# Spiky 核梯度 → 压力推开
				f_press += -dir * (pres[i] + pres[j]) * 0.5 * x * x / dens[j]
				# 粘性 → 速度趋同
				f_visc += (vel[j] - vel[i]) * x / dens[j]
		var force := f_press * 0.02 + f_visc * VISCOSITY * 0.0008 + GRAVITY * dens[i]
		vel[i] += force / dens[i] * dt
		pos[i] += vel[i] * dt
		_bounds(i)

func _bounds(i: int) -> void:
	var p := pos[i]
	var v := vel[i]
	var pad := 8.0
	if p.x < pad: p.x = pad; v.x = absf(v.x) * DAMPING
	if p.x > BOUNDS.x - pad: p.x = BOUNDS.x - pad; v.x = -absf(v.x) * DAMPING
	if p.y < pad + 70: p.y = pad + 70; v.y = absf(v.y) * DAMPING
	if p.y > BOUNDS.y - pad: p.y = BOUNDS.y - pad; v.y = -absf(v.y) * DAMPING
	pos[i] = p
	vel[i] = v

func _handle_mouse(dt: float) -> void:
	var mp := get_global_mouse_position()
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		for i in count:
			var d := pos[i].distance_to(mp)
			if d < 120.0:
				vel[i] += (mp - pos[i]).normalized() * 600.0 * dt
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		for i in count:
			var d := pos[i].distance_to(mp)
			if d < 140.0 and d > 0.1:
				vel[i] += (pos[i] - mp).normalized() * 1400.0 * dt

func _draw_fluid() -> void:
	for i in count:
		# 颜色按速度大小:慢=蓝,快=青白
		var speed := vel[i].length()
		var t: float = clamp(speed / 400.0, 0.0, 1.0)
		var col := Color(0.2 + t * 0.5, 0.5 + t * 0.4, 1.0, 0.9)
		renderer.draw_circle(pos[i], 7.0, col)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R: _reset()
			KEY_EQUAL, KEY_KP_ADD:
				count = min(900, count + 100); _reset()
			KEY_MINUS, KEY_KP_SUBTRACT:
				count = max(100, count - 100); _reset()
