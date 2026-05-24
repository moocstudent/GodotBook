extends Node2D

# ╔══════════════════════════════════════════════════════════════╗
# ║  毕业作 — Coin Dash                                            ║
# ║  整合:平台移动(03)· 拾取/实例化(05)· 粒子(13)·            ║
# ║        合成音效(09)· 存档(06/22)· 加载/状态流(33)         ║
# ║                                                              ║
# ║  游戏状态机:TITLE → PLAYING ⇄ PAUSED → WON / LOST            ║
# ║  暂停用 get_tree().paused;Main 节点 process_mode=ALWAYS,      ║
# ║  World 节点 process_mode=PAUSABLE,所以暂停只冻结游戏世界,     ║
# ║  HUD 和输入仍响应。                                           ║
# ╚══════════════════════════════════════════════════════════════╝

enum State { TITLE, PLAYING, PAUSED, WON, LOST }
const SAVE_PATH := "user://coin_dash.json"

@onready var world: Node2D = $World
@onready var player: CharacterBody2D = %Player
@onready var coins_node: Node2D = %Coins
@onready var fx: Node2D = %FX
@onready var hazard: Area2D = %Hazard
@onready var goal: Area2D = %Goal

var state: int = State.TITLE
var score := 0
var coins_total := 0
var coins_left := 0
var time := 0.0
var best := -1.0

var sfx: Sfx

# HUD(代码构建)
var info: Label
var overlay: Control
var big: Label
var hint: Label

func _ready() -> void:
	sfx = Sfx.new()
	add_child(sfx)
	_build_hud()
	_load_best()

	coins_total = coins_node.get_child_count()
	coins_left = coins_total
	for c in coins_node.get_children():
		c.collected.connect(_on_coin_collected)
	hazard.body_entered.connect(_on_hazard)
	goal.body_entered.connect(_on_goal)
	player.jumped.connect(sfx.jump)

	_enter_title()

# ── HUD ───────────────────────────────────────────────────────

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)

	info = Label.new()
	info.position = Vector2(16, 12)
	info.add_theme_font_size_override("font_size", 20)
	hud.add_child(info)

	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	overlay.add_child(vbox)

	big = Label.new()
	big.add_theme_font_size_override("font_size", 52)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(big)

	hint = Label.new()
	hint.add_theme_font_size_override("font_size", 20)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.8)
	vbox.add_child(hint)

func _process(delta: float) -> void:
	if state == State.PLAYING:
		time += delta
	var best_str := ("%.2fs" % best) if best >= 0 else "—"
	info.text = "金币 %d/%d   分数 %d   时间 %.1fs   最佳 %s" % [
		coins_total - coins_left, coins_total, score, time, best_str
	]

# ── 状态切换 ──────────────────────────────────────────────────

func _enter_title() -> void:
	state = State.TITLE
	get_tree().paused = true
	_show_overlay("COIN DASH", "WASD/方向键移动 · 空格跳 · 集齐金币到终点\n躲开红色岩浆 · Esc 暂停 · R 重开\n\n[ 按 空格 开始 ]")

func _start() -> void:
	state = State.PLAYING
	get_tree().paused = false
	_hide_overlay()

func _toggle_pause() -> void:
	if state == State.PLAYING:
		state = State.PAUSED
		get_tree().paused = true
		_show_overlay("暂停", "Esc 继续 · R 重开")
	elif state == State.PAUSED:
		_start()

func _win() -> void:
	state = State.WON
	get_tree().paused = true
	sfx.win()
	var record := ""
	if best < 0 or time < best:
		best = time
		_save_best()
		record = "  ★ 新纪录!"
	_show_overlay("过关!", "用时 %.2fs%s\n分数 %d\n\n[ 按 R 再来一局 ]" % [time, record, score])

func _lose() -> void:
	state = State.LOST
	get_tree().paused = true
	sfx.lose()
	_show_overlay("失败", "碰到岩浆了\n\n[ 按 R 重来 ]")

func _show_overlay(title: String, sub: String) -> void:
	big.text = title
	hint.text = sub
	overlay.visible = true

func _hide_overlay() -> void:
	overlay.visible = false

# ── 事件 ─────────────────────────────────────────────────────

func _on_coin_collected(coin: Area2D) -> void:
	if state != State.PLAYING:
		return
	score += 10
	coins_left -= 1
	sfx.coin()
	_spawn_pickup_fx(coin.global_position)
	if coins_left == 0 and goal.has_node("V"):
		(goal.get_node("V") as ColorRect).color = Color(0.45, 1.0, 0.55, 1)  # 终点点亮

func _on_hazard(body: Node) -> void:
	if state == State.PLAYING and body is CharacterBody2D:
		_lose()

func _on_goal(body: Node) -> void:
	if state == State.PLAYING and body is CharacterBody2D:
		if coins_left == 0:
			_win()
		else:
			_flash_hint("还差 %d 个金币!" % coins_left)

func _flash_hint(msg: String) -> void:
	info.text = msg
	# 简易闪一下(不打断游戏)
	var t := create_tween()
	info.modulate = Color(1, 0.6, 0.3)
	t.tween_property(info, "modulate", Color.WHITE, 0.6)

# ── 拾取粒子(沿用 demo 13 的 CPUParticles 思路)──────────────

func _spawn_pickup_fx(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.emitting = true
	p.one_shot = true
	p.amount = 18
	p.lifetime = 0.5
	p.explosiveness = 0.9
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 200.0
	p.gravity = Vector2(0, 300)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = Color(1, 0.85, 0.3)
	fx.add_child(p)
	get_tree().create_timer(0.8).timeout.connect(p.queue_free)

# ── 存档 ─────────────────────────────────────────────────────

func _load_best() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		var d: Variant = JSON.parse_string(f.get_as_text())
		if typeof(d) == TYPE_DICTIONARY:
			best = float(d.get("best", -1.0))

func _save_best() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({ "best": best }))

# ── 输入(Main=ALWAYS,暂停时也响应)──────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().paused = false
		get_tree().reload_current_scene()
		return

	match state:
		State.TITLE:
			if event.is_action_pressed("jump"):
				_start()
		State.PLAYING:
			if event.is_action_pressed("pause"):
				_toggle_pause()
		State.PAUSED:
			if event.is_action_pressed("pause"):
				_toggle_pause()
