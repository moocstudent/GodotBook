extends Node2D
class_name Enemy

# 用上面的 BT 框架搭一个敌人 AI:
#
#   Selector "root"
#   ├── Sequence "flee"      (血量低 → 逃离玩家)
#   │   ├── Condition  low_health?
#   │   └── Action     flee_from_player
#   ├── Sequence "attack"    (玩家很近 → 攻击)
#   │   ├── Condition  player_in_attack_range?
#   │   └── Action     attack
#   ├── Sequence "chase"     (玩家在视野 → 追击)
#   │   ├── Condition  player_in_sight?
#   │   └── Action     chase_player
#   └── Action "patrol"      (默认 → 巡逻)

@export var speed := 140.0
@export var sight_range := 280.0
@export var attack_range := 56.0
@export var max_health := 100.0

var health: float
var player: Node2D
var _tree: BT.Node
var _attack_cooldown := 0.0
var _patrol_target: Vector2
var current_state := "?"

@onready var body: ColorRect = $Body
@onready var label: Label = $StateLabel

func setup(p: Node2D) -> void:
	player = p

func _ready() -> void:
	health = max_health
	_pick_new_patrol()
	_build_tree()

func _build_tree() -> void:
	_tree = BT.Selector.new("root", [
		BT.Sequence.new("flee", [
			BT.Condition.new("low_health?", _cond_low_health),
			BT.Action.new("flee", _act_flee),
		]),
		BT.Sequence.new("attack", [
			BT.Condition.new("in_attack_range?", _cond_attack_range),
			BT.Action.new("attack", _act_attack),
		]),
		BT.Sequence.new("chase", [
			BT.Condition.new("player_in_sight?", _cond_in_sight),
			BT.Action.new("chase", _act_chase),
		]),
		BT.Action.new("patrol", _act_patrol),
	])

func _physics_process(delta: float) -> void:
	_attack_cooldown = max(0.0, _attack_cooldown - delta)
	_tree.tick(self, delta)
	current_state = _tree.active_leaf()
	_update_visual()

func _update_visual() -> void:
	var c := Color.GRAY
	match current_state:
		"flee":   c = Color(0.6, 0.4, 0.95)
		"attack": c = Color(0.95, 0.3, 0.3)
		"chase":  c = Color(0.95, 0.6, 0.2)
		"patrol": c = Color(0.4, 0.7, 0.5)
	body.color = c
	label.text = "%s  hp:%d" % [current_state, int(health)]

# ── Conditions ────────────────────────────────────────────────

func _cond_low_health(_a) -> bool:
	return health < max_health * 0.3

func _cond_attack_range(_a) -> bool:
	return _dist_to_player() < attack_range

func _cond_in_sight(_a) -> bool:
	return _dist_to_player() < sight_range

# ── Actions(返回 BT.Status)────────────────────────────────────

func _act_flee(_a, delta: float) -> int:
	var dir := (global_position - player.global_position).normalized()
	global_position += dir * speed * 1.2 * delta
	_clamp_pos()
	return BT.Status.RUNNING   # 一直逃,直到血回升(本 demo 不回血,演示持续 RUNNING)

func _act_attack(_a, _delta: float) -> int:
	if _attack_cooldown <= 0.0:
		_attack_cooldown = 0.8
		# 这里可以 emit 信号造成伤害;demo 仅闪一下
		var t := create_tween()
		body.scale = Vector2(1.4, 1.4)
		t.tween_property(body, "scale", Vector2.ONE, 0.2)
	return BT.Status.RUNNING

func _act_chase(_a, delta: float) -> int:
	var dir := (player.global_position - global_position).normalized()
	global_position += dir * speed * delta
	_clamp_pos()
	# 追到攻击距离内就让出控制权(返回 SUCCESS,让 Selector 下一帧重新评估到 attack)
	return BT.Status.SUCCESS if _dist_to_player() < attack_range else BT.Status.RUNNING

func _act_patrol(_a, delta: float) -> int:
	var dir := (_patrol_target - global_position)
	if dir.length() < 16.0:
		_pick_new_patrol()
		return BT.Status.SUCCESS
	global_position += dir.normalized() * speed * 0.6 * delta
	_clamp_pos()
	return BT.Status.RUNNING

# ── helpers ───────────────────────────────────────────────────

func _dist_to_player() -> float:
	return global_position.distance_to(player.global_position) if player else 99999.0

func _pick_new_patrol() -> void:
	_patrol_target = Vector2(randf_range(80, 1072), randf_range(120, 560))

func _clamp_pos() -> void:
	global_position.x = clamp(global_position.x, 30, 1122)
	global_position.y = clamp(global_position.y, 80, 600)

func take_damage(amount: float) -> void:
	health = max(0.0, health - amount)
