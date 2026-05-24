extends Node2D

var velocity := Vector2.ZERO
var life := 0.0
var max_life := 1.5
var pool                       # 设了 pool = 用对象池模式;否则 queue_free

func on_spawn() -> void:
	# 对象池复用时重置状态
	visible = true
	life = 0.0
	var a := randf() * TAU
	velocity = Vector2(cos(a), sin(a)) * randf_range(80, 260)
	$Visual.color = Color.from_hsv(randf(), 0.7, 1.0)

func _process(delta: float) -> void:
	position += velocity * delta
	velocity.y += 320.0 * delta
	life += delta
	if life >= max_life:
		if pool:
			pool.release(self)     # 回收
		else:
			queue_free()           # 销毁(对照组)
