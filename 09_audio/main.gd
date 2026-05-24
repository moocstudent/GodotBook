extends Control

# SFX 池大小:同一帧能播多少个独立音
const SFX_POOL_SIZE := 8

@onready var low_btn: Button = %LowBeep
@onready var mid_btn: Button = %MidBeep
@onready var high_btn: Button = %HighBeep
@onready var rapid_btn: Button = %RapidButton
@onready var music_btn: Button = %MusicButton

@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SFXSlider
@onready var master_value: Label = %MasterValue
@onready var music_value: Label = %MusicValue
@onready var sfx_value: Label = %SFXValue
@onready var status: Label = %StatusLabel

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_idx: int = 0
var _music_player: AudioStreamPlayer
var _beeps := {}                   # 缓存生成的 AudioStreamWAV

var _music_bus_idx: int
var _sfx_bus_idx: int

func _ready() -> void:
	_setup_buses()
	_build_streams()
	_build_sfx_pool()
	_build_music_player()
	_wire_ui()
	_apply_volumes()
	status.text = "拖滑块改 dB · 注意 Music 推子是 Music bus,Beep 在 SFX bus"

# ── (1) 加 Music / SFX 两条 bus,都送到 Master ─────────────────

func _setup_buses() -> void:
	# Master 是 bus 0,总是存在
	_music_bus_idx = AudioServer.bus_count
	AudioServer.add_bus(_music_bus_idx)
	AudioServer.set_bus_name(_music_bus_idx, "Music")
	AudioServer.set_bus_send(_music_bus_idx, "Master")

	_sfx_bus_idx = AudioServer.bus_count
	AudioServer.add_bus(_sfx_bus_idx)
	AudioServer.set_bus_name(_sfx_bus_idx, "SFX")
	AudioServer.set_bus_send(_sfx_bus_idx, "Master")

# ── (2) 程序化生成所有音频 ────────────────────────────────────

func _build_streams() -> void:
	_beeps["low"]  = BeepFactory.sine_beep(220.0, 0.18)
	_beeps["mid"]  = BeepFactory.sine_beep(440.0, 0.18)
	_beeps["high"] = BeepFactory.sine_beep(880.0, 0.15)
	_beeps["pew"]  = BeepFactory.sine_beep(660.0, 0.08, 22050, 0.35)

# ── (3) SFX 池:多个 player 轮转,避免 "重复触发把自己截断" ────

func _build_sfx_pool() -> void:
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)

func _play_sfx(stream: AudioStream) -> void:
	# 轮询找一个空闲的;都不空就强占下一个
	for n in SFX_POOL_SIZE:
		var idx := (_sfx_pool_idx + n) % SFX_POOL_SIZE
		var p := _sfx_pool[idx]
		if not p.playing:
			p.stream = stream
			p.play()
			_sfx_pool_idx = (idx + 1) % SFX_POOL_SIZE
			return
	# 全忙 -> 抢占
	var p := _sfx_pool[_sfx_pool_idx]
	p.stop()
	p.stream = stream
	p.play()
	_sfx_pool_idx = (_sfx_pool_idx + 1) % SFX_POOL_SIZE

# ── (4) Music:一个常驻 player,toggle 开关 ────────────────────

func _build_music_player() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	# C major 三度叠加,1.0 秒循环 -> 永远缓缓 hum
	_music_player.stream = BeepFactory.looping_chord(
		PackedFloat32Array([261.6, 329.6, 392.0]),
		1.0
	)
	add_child(_music_player)

# ── (5) UI 连接 ───────────────────────────────────────────────

func _wire_ui() -> void:
	low_btn.pressed.connect(func(): _play_sfx(_beeps["low"]))
	mid_btn.pressed.connect(func(): _play_sfx(_beeps["mid"]))
	high_btn.pressed.connect(func(): _play_sfx(_beeps["high"]))

	rapid_btn.button_down.connect(_start_rapid)
	rapid_btn.button_up.connect(_stop_rapid)

	music_btn.pressed.connect(_toggle_music)

	master_slider.value_changed.connect(func(_v): _apply_volumes())
	music_slider.value_changed.connect(func(_v): _apply_volumes())
	sfx_slider.value_changed.connect(func(_v): _apply_volumes())

func _apply_volumes() -> void:
	AudioServer.set_bus_volume_db(0, master_slider.value)             # Master
	AudioServer.set_bus_volume_db(_music_bus_idx, music_slider.value)
	AudioServer.set_bus_volume_db(_sfx_bus_idx, sfx_slider.value)
	master_value.text = "%d dB" % master_slider.value
	music_value.text  = "%d dB" % music_slider.value
	sfx_value.text    = "%d dB" % sfx_slider.value

# ── (6) Rapid fire 演示池的价值 ───────────────────────────────

var _rapid_timer := 0.0
var _rapid_on := false

func _start_rapid() -> void:
	_rapid_on = true

func _stop_rapid() -> void:
	_rapid_on = false

func _process(delta: float) -> void:
	if _rapid_on:
		_rapid_timer -= delta
		if _rapid_timer <= 0.0:
			_play_sfx(_beeps["pew"])
			_rapid_timer = 0.06   # 每 60ms 一发

func _toggle_music() -> void:
	if _music_player.playing:
		_music_player.stop()
		music_btn.text = "▶ Music ON / OFF (Music Bus)"
	else:
		_music_player.play()
		music_btn.text = "■ Music ON / OFF (Music Bus)"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
