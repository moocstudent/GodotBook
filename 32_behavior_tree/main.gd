extends Node2D

const EnemyScript := preload("res://enemy.gd")

@onready var player: Node2D = %Player
@onready var enemies_node: Node2D = %Enemies
@onready var legend: Label = $LegendLabel

@export var player_speed := 320.0

func _ready() -> void:
	for i in 4:
		_spawn_enemy(Vector2(200 + i * 240, 200 + (i % 2) * 200))

func _spawn_enemy(pos: Vector2) -> void:
	var e := Node2D.new()
	e.set_script(EnemyScript)
	e.position = pos

	var body := ColorRect.new()
	body.name = "Body"
	body.offset_left = -16; body.offset_top = -16
	body.offset_right = 16; body.offset_bottom = 16
	body.color = Color.GRAY
	e.add_child(body)

	var label := Label.new()
	label.name = "StateLabel"
	label.offset_left = -40; label.offset_top = -42
	label.offset_right = 40; label.offset_bottom = -20
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.add_child(label)

	enemies_node.add_child(e)
	e.setup(player)

func _process(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	player.position += dir * player_speed * delta
	player.position.x = clamp(player.position.x, 12, 1140)
	player.position.y = clamp(player.position.y, 88, 636)

	var states := {}
	for e in enemies_node.get_children():
		var s: String = e.current_state
		states[s] = states.get(s, 0) + 1
	legend.text = "enemies by state: " + str(states)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_K:
		# 给最近的敌人砍 40 血,观察它切到"逃跑"
		var nearest: Node2D = null
		var best := 1e9
		for e in enemies_node.get_children():
			var d: float = e.global_position.distance_to(player.global_position)
			if d < best:
				best = d; nearest = e
		if nearest:
			nearest.take_damage(40.0)
