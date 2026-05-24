extends Area2D

@export var speed: float = 600.0
@export var lifetime: float = 2.0          # 秒,自动消失
@export var direction: Vector2 = Vector2.UP

var _age: float = 0.0

func _process(delta: float) -> void:
	position += direction * speed * delta
	_age += delta
	if _age >= lifetime:
		queue_free()                         # 安全释放:本帧末尾真正销毁

	# 也兼顾出屏即销毁,防止子弹漂到天边浪费内存
	var vp := get_viewport_rect()
	if not vp.grow(64).has_point(position):
		queue_free()
