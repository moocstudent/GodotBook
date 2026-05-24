extends Node2D

const ParticleScene := preload("res://particle.tscn")

@onready var spawn_parent: Node2D = %Spawn

var profiler: Profiler
var pool: ObjectPool
var use_pool := true
var spawn_rate := 60          # 每帧喷几个

func _ready() -> void:
	profiler = Profiler.new()
	add_child(profiler)
	pool = ObjectPool.new(ParticleScene, spawn_parent, 200)   # 预热 200

func _process(_delta: float) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		profiler.begin("spawn")
		_spawn_burst(get_global_mouse_position())
		profiler.end("spawn")

	profiler.custom_text = "mode: %s   spawn_rate: %d/frame   pool[active=%d free=%d created=%d]" % [
		"OBJECT POOL" if use_pool else "new / queue_free",
		spawn_rate,
		pool.active_count(), pool.free_count(), pool.created_total
	]

func _spawn_burst(at: Vector2) -> void:
	for i in spawn_rate:
		if use_pool:
			var p := pool.acquire()
			p.position = at
			p.pool = pool
		else:
			# 对照组:每次真 new + 进树,死了 queue_free
			var p := ParticleScene.instantiate()
			p.position = at
			p.pool = null
			spawn_parent.add_child(p)
			p.on_spawn()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_P:
				use_pool = not use_pool
				# 清场,避免两种模式的残留混在一起
				for c in spawn_parent.get_children():
					c.queue_free()
				pool = ObjectPool.new(ParticleScene, spawn_parent, 200 if use_pool else 0)
			KEY_EQUAL, KEY_KP_ADD:
				spawn_rate = min(400, spawn_rate + 20)
			KEY_MINUS, KEY_KP_SUBTRACT:
				spawn_rate = max(20, spawn_rate - 20)
