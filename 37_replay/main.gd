extends Node2D

# ╔══════════════════════════════════════════════════════════════╗
# ║  确定性回放(deterministic replay)                            ║
# ║                                                              ║
# ║  核心思想:不录"位置",录"输入"。只要                          ║
# ║   (1) 固定步长(_physics_process)                            ║
# ║   (2) 模拟是输入的纯函数(同样输入 → 同样结果)                ║
# ║  那么回放时把录下的输入按帧喂回去,就能 100% 复现。            ║
# ║                                                              ║
# ║  好处:录像文件极小(只存输入,不存每帧坐标),还能做           ║
# ║  联机对战回放、反作弊验证、ghost 竞速。                        ║
# ╚══════════════════════════════════════════════════════════════╝

enum Mode { LIVE, RECORDING, REPLAYING }

const SAVE_PATH := "user://replay.json"
const SPEED := 280.0

@onready var player: Node2D = %Player
@onready var trail: Node2D = %Trail
@onready var status: Label = %StatusLabel

var mode := Mode.LIVE
var frame := 0
var recording: Array = []        # 每帧一个输入快照
var replay_frame := 0
var start_pos := Vector2(576, 360)

func _ready() -> void:
	# 固定 60Hz 物理步长(确定性的前提)
	Engine.physics_ticks_per_second = 60

func _physics_process(_delta: float) -> void:
	var input := _sample_or_replay_input()
	_simulate(input)             # 模拟 = 纯函数(input → 状态变化)
	frame += 1
	_update_status()

# 取输入:LIVE/RECORDING 读真实键盘;REPLAYING 从录像读
func _sample_or_replay_input() -> Dictionary:
	if mode == Mode.REPLAYING:
		if replay_frame >= recording.size():
			_stop_replay()
			return _empty_input()
		var snap: Dictionary = recording[replay_frame]
		replay_frame += 1
		return snap

	var input := {
		"x": Input.get_axis("move_left", "move_right"),
		"y": Input.get_axis("move_up", "move_down"),
		"fire": Input.is_action_pressed("fire"),
	}
	if mode == Mode.RECORDING:
		recording.append(input)
	return input

func _empty_input() -> Dictionary:
	return { "x": 0.0, "y": 0.0, "fire": false }

# 纯模拟:只依赖 input,不读全局随机/时间(否则不确定)
func _simulate(input: Dictionary) -> void:
	var dt := 1.0 / 60.0
	player.position += Vector2(input.x, input.y) * SPEED * dt
	player.position.x = clamp(player.position.x, 16, 1136)
	player.position.y = clamp(player.position.y, 88, 632)
	if input.fire:
		_drop_trail(player.position)

func _drop_trail(pos: Vector2) -> void:
	var dot := ColorRect.new()
	dot.offset_left = -3; dot.offset_top = -3
	dot.offset_right = 3; dot.offset_bottom = 3
	dot.position = pos
	dot.color = Color(1, 0.7, 0.3, 0.8) if mode != Mode.REPLAYING else Color(0.5, 1, 0.6, 0.8)
	trail.add_child(dot)

# ── 控制 ─────────────────────────────────────────────────────

func _start_recording() -> void:
	_reset_world()
	recording.clear()
	frame = 0
	mode = Mode.RECORDING

func _stop() -> void:
	mode = Mode.LIVE

func _start_replay() -> void:
	if recording.is_empty():
		return
	_reset_world()
	replay_frame = 0
	frame = 0
	mode = Mode.REPLAYING

func _stop_replay() -> void:
	mode = Mode.LIVE

func _reset_world() -> void:
	player.position = start_pos
	for c in trail.get_children():
		c.queue_free()

# ── 存盘 / 读盘 ───────────────────────────────────────────────

func _save_replay() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"version": 1,
		"physics_hz": 60,
		"start_pos": [start_pos.x, start_pos.y],
		"frames": recording,
	}))

func _load_and_replay() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var d: Variant = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return
	recording = d.get("frames", [])
	_start_replay()

func _update_status() -> void:
	var mode_str := ["LIVE", "● RECORDING", "▶ REPLAYING"][mode]
	status.text = "%s · frame=%d · recorded=%d frames (%.1fs) · 文件: %s" % [
		mode_str, frame, recording.size(), recording.size() / 60.0,
		ProjectSettings.globalize_path(SAVE_PATH)
	]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1: _start_recording()
			KEY_2: _stop()
			KEY_3: _start_replay()
			KEY_4: _save_replay()
			KEY_5: _load_and_replay()
