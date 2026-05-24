extends Area2D

# 金币:玩家碰到 -> 发信号 + 自毁(粒子由 game 生成)。
signal collected(coin: Area2D)

var _t := 0.0

func _ready() -> void:
	body_entered.connect(_on_body)

func _process(delta: float) -> void:
	# 上下浮动 + 旋转,显得有活力
	_t += delta
	position.y += sin(_t * 3.0) * 0.4
	$Visual.rotation += delta * 2.0

func _on_body(body: Node) -> void:
	if body is CharacterBody2D:
		collected.emit(self)
		set_deferred("monitoring", false)
		queue_free()
