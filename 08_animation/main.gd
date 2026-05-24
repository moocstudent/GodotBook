extends Node2D

@onready var tween_target: Button = %TweenTarget
@onready var queue_target: ColorRect = %QueueTarget
@onready var queue_button: Button = %QueueButton
@onready var anim_target: ColorRect = %AnimTarget
@onready var anim_player: AnimationPlayer = %AnimPlayer
@onready var status: Label = %StatusLabel

# 把循环动画做的"原位"中心点记下来,后续从这里开始动
var _anim_origin: Vector2
var _queue_origin: Vector2

func _ready() -> void:
	_anim_origin = anim_target.position
	_queue_origin = queue_target.position

	# 1) Tween:点击按钮触发一次性弹跳
	tween_target.pressed.connect(_bounce_tween)

	# 2) AnimationPlayer:用代码构造动画库,然后循环播放
	_setup_anim_player()
	anim_player.play("idle_loop")

	# 3) 队列播放:点按钮 -> intro 播完 -> 自动接 idle
	queue_button.pressed.connect(_play_queue)
	anim_player.animation_finished.connect(_on_anim_finished)

	status.text = "Tween / 时间轴 / 队列 三种动画风格并排对比"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

# ── (1) Tween:命令式、可链式、最常用 ──────────────────────────────

func _bounce_tween() -> void:
	# 之前的 tween 如果还活着,kill 掉防止冲突
	var t := create_tween()
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# parallel:两条轨道并行;否则串行
	t.tween_property(tween_target, "scale", Vector2(1.3, 1.3), 0.1)
	t.tween_property(tween_target, "scale", Vector2.ONE, 0.3)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# 同时改颜色
	t.parallel().tween_property(tween_target, "modulate",
		Color(1.0, 0.8, 0.4, 1.0), 0.1)
	t.tween_property(tween_target, "modulate", Color.WHITE, 0.3)

# ── (2) AnimationPlayer:声明式、可视化、复杂动画首选 ────────────

func _setup_anim_player() -> void:
	# 用代码构造 3 个 Animation 资源:idle_loop / intro / pulse
	var lib := AnimationLibrary.new()
	lib.add_animation("idle_loop", _make_idle_anim())
	lib.add_animation("intro", _make_intro_anim())
	lib.add_animation("pulse", _make_pulse_anim())
	# 库名留空 -> 动画名就是 "idle_loop" 而不是 "lib/idle_loop"
	anim_player.add_animation_library("", lib)

func _make_idle_anim() -> Animation:
	# 循环呼吸:scale 在 1.0 和 1.1 之间正弦摆动
	var anim := Animation.new()
	anim.length = 1.6
	anim.loop_mode = Animation.LOOP_LINEAR

	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, "../AnimTarget:scale")
	anim.track_insert_key(track, 0.0, Vector2.ONE)
	anim.track_insert_key(track, 0.8, Vector2(1.12, 0.92))
	anim.track_insert_key(track, 1.6, Vector2.ONE)
	return anim

func _make_intro_anim() -> Animation:
	# 一次性"入场":从右上飞进来,落到原位
	var anim := Animation.new()
	anim.length = 0.6
	anim.loop_mode = Animation.LOOP_NONE

	var pos_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(pos_track, "../QueueTarget:position")
	anim.track_insert_key(pos_track, 0.0, _queue_origin + Vector2(300, -200))
	anim.track_insert_key(pos_track, 0.6, _queue_origin)

	var mod_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(mod_track, "../QueueTarget:modulate")
	anim.track_insert_key(mod_track, 0.0, Color(1, 1, 1, 0))
	anim.track_insert_key(mod_track, 0.6, Color.WHITE)
	return anim

func _make_pulse_anim() -> Animation:
	# 持续脉动,接在 intro 之后
	var anim := Animation.new()
	anim.length = 1.0
	anim.loop_mode = Animation.LOOP_LINEAR

	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, "../QueueTarget:scale")
	anim.track_insert_key(track, 0.0, Vector2.ONE)
	anim.track_insert_key(track, 0.5, Vector2(1.15, 1.15))
	anim.track_insert_key(track, 1.0, Vector2.ONE)
	return anim

# ── (3) 队列:intro 播完自动接 pulse ─────────────────────────────

func _play_queue() -> void:
	queue_target.position = _queue_origin + Vector2(300, -200)
	queue_target.modulate = Color(1, 1, 1, 0)
	anim_player.play("intro")
	anim_player.queue("pulse")
	status.text = "队列: intro → pulse(完成时会触发 animation_finished)"

func _on_anim_finished(anim_name: StringName) -> void:
	status.text = "animation_finished: %s" % anim_name
