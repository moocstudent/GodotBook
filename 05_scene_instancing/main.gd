extends Node2D

# preload 在编译期把场景打到二进制里 -> 取的是同一个 PackedScene 资源
const BulletScene: PackedScene = preload("res://bullet.tscn")

@export var player_speed: float = 360.0

@onready var player: Sprite2D = %Player
@onready var muzzle: Marker2D = $Player/Muzzle
@onready var bullets_parent: Node2D = %Bullets
@onready var auto_timer: Timer = %AutoFireTimer
@onready var stats: Label = %StatsLabel

func _ready() -> void:
	auto_timer.timeout.connect(_on_auto_fire)

func _process(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	player.position.x += dir * player_speed * delta
	player.position.x = clamp(player.position.x, 20.0, 1132.0)

	if Input.is_action_just_pressed("shoot"):
		_fire_bullet()

	stats.text = "Active bullets: %d" % bullets_parent.get_child_count()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

# —— 核心:把 PackedScene 实例化、挂进树 ————————————————————————

func _fire_bullet() -> void:
	# instantiate() 会拷贝一份场景节点树,返回根节点
	var b: Area2D = BulletScene.instantiate()
	b.position = muzzle.global_position
	b.direction = Vector2.UP

	# 必须 add_child 到某个已在场景树里的节点,bullet 才会被 _process / 渲染
	bullets_parent.add_child(b)

func _on_auto_fire() -> void:
	# 自动开火两边斜飞,演示同一个 PackedScene 多重实例化
	for offset in [-0.3, 0.0, 0.3]:
		var b: Area2D = BulletScene.instantiate()
		b.position = muzzle.global_position
		b.direction = Vector2.UP.rotated(offset)
		b.speed = 380.0
		bullets_parent.add_child(b)
