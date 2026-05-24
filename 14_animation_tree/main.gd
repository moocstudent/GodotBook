extends Node2D

@onready var player: Node2D = %Player
@onready var body: ColorRect = %Body
@onready var anim_player: AnimationPlayer = %AnimPlayer
@onready var anim_tree: AnimationTree = %AnimTree
@onready var state_label: Label = %StateLabel

@export var move_speed: float = 260.0

# velocity 只是为了让"地面玩家"也有点移动感
var _vel := Vector2.ZERO

func _ready() -> void:
	_build_animations()
	_build_animation_tree()
	anim_tree.active = true

func _physics_process(delta: float) -> void:
	# 输入 → 速度
	var dir := Input.get_axis("move_left", "move_right")
	_vel.x = dir * move_speed
	player.position.x = clamp(player.position.x + _vel.x * delta, 40, 1112)

	# 朝向(让方块"看"移动方向 -> 简单 flip)
	if dir != 0:
		body.scale.x = -1 if dir < 0 else 1

	# === 给 AnimationTree 喂条件参数 ===
	# `parameters/conditions/<name>` = 该 transition 是否允许通过
	var walking := absf(_vel.x) > 1.0
	anim_tree.set("parameters/conditions/is_walking", walking)
	anim_tree.set("parameters/conditions/is_idle", not walking)

	# 跳跃用 travel(),无视 transition 条件直接切到 jump,播完自然回 idle/walk
	if Input.is_action_just_pressed("jump"):
		var pb: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")
		pb.travel("jump")

	_refresh_state_label()

func _refresh_state_label() -> void:
	var pb: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")
	state_label.text = "state: %s · is_walking=%s · is_idle=%s" % [
		pb.get_current_node(),
		anim_tree.get("parameters/conditions/is_walking"),
		anim_tree.get("parameters/conditions/is_idle"),
	]

# ── 程序化构造 3 个动画 ───────────────────────────────────────

func _build_animations() -> void:
	var lib := AnimationLibrary.new()
	lib.add_animation("idle", _make_idle())
	lib.add_animation("walk", _make_walk())
	lib.add_animation("jump", _make_jump())
	anim_player.add_animation_library("", lib)

func _make_idle() -> Animation:
	# 缓慢呼吸:scale y 在 1.0 / 0.97 之间
	var a := Animation.new()
	a.length = 1.6
	a.loop_mode = Animation.LOOP_LINEAR
	var tr := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tr, "Body:scale")
	a.track_insert_key(tr, 0.0, Vector2(1, 1))
	a.track_insert_key(tr, 0.8, Vector2(1.02, 0.97))
	a.track_insert_key(tr, 1.6, Vector2(1, 1))
	return a

func _make_walk() -> Animation:
	# 弹跳:y 在 0 / -10 之间;同时旋转一点
	var a := Animation.new()
	a.length = 0.4
	a.loop_mode = Animation.LOOP_LINEAR

	var ty := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(ty, "Body:position:y")
	a.track_insert_key(ty, 0.0, 0.0)
	a.track_insert_key(ty, 0.1, -10.0)
	a.track_insert_key(ty, 0.2, 0.0)
	a.track_insert_key(ty, 0.3, -10.0)
	a.track_insert_key(ty, 0.4, 0.0)

	var tr := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tr, "Body:rotation")
	a.track_insert_key(tr, 0.0, 0.0)
	a.track_insert_key(tr, 0.1, 0.06)
	a.track_insert_key(tr, 0.2, 0.0)
	a.track_insert_key(tr, 0.3, -0.06)
	a.track_insert_key(tr, 0.4, 0.0)
	return a

func _make_jump() -> Animation:
	# 一次性:蓄力 -> 弹起 -> 回正,有 squash & stretch
	var a := Animation.new()
	a.length = 0.55
	a.loop_mode = Animation.LOOP_NONE

	var ts := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(ts, "Body:scale")
	a.track_insert_key(ts, 0.0, Vector2(1.0, 1.0))
	a.track_insert_key(ts, 0.08, Vector2(1.2, 0.7))  # 蓄力
	a.track_insert_key(ts, 0.20, Vector2(0.85, 1.25)) # 拉伸
	a.track_insert_key(ts, 0.50, Vector2(1.0, 1.0))

	var ty := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(ty, "Body:position:y")
	a.track_insert_key(ty, 0.0, 0.0)
	a.track_insert_key(ty, 0.08, 6.0)
	a.track_insert_key(ty, 0.30, -80.0)               # 顶点
	a.track_insert_key(ty, 0.50, 0.0)
	return a

# ── 程序化构造 AnimationTree 状态机 ──────────────────────────

func _build_animation_tree() -> void:
	anim_tree.anim_player = anim_tree.get_path_to(anim_player)

	var sm := AnimationNodeStateMachine.new()

	# 叶子:每个状态包一个 Animation 节点指向 lib 里的同名动画
	sm.add_node("idle", _anim_node("idle"), Vector2(120, 100))
	sm.add_node("walk", _anim_node("walk"), Vector2(320, 100))
	sm.add_node("jump", _anim_node("jump"), Vector2(520, 100))

	# 起始
	sm.set_start_node("idle")

	# idle -> walk(条件:is_walking)
	sm.add_transition("idle", "walk", _transition("is_walking"))
	# walk -> idle(条件:is_idle)
	sm.add_transition("walk", "idle", _transition("is_idle"))

	# Any -> jump 用代码 travel() 触发,不配自动 transition
	# jump 结束 -> idle(advance_mode = AUTO,等动画播完自然切)
	var t_auto := AnimationNodeStateMachineTransition.new()
	t_auto.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
	t_auto.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	sm.add_transition("jump", "idle", t_auto)

	anim_tree.tree_root = sm

func _anim_node(anim_name: String) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = anim_name
	return n

func _transition(condition_name: String) -> AnimationNodeStateMachineTransition:
	var t := AnimationNodeStateMachineTransition.new()
	t.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	t.advance_condition = condition_name
	t.xfade_time = 0.15   # 状态切换的过渡时间(交叉淡入)
	return t

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
