extends Node
class_name Sfx

# 程序化合成音效(无音频文件依赖,沿用 demo 09 的思路)。
# 几个 AudioStreamPlayer 轮流播,避免互相打断。

const RATE := 22050
var _players: Array[AudioStreamPlayer] = []
var _next := 0

func _ready() -> void:
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)

func _tone(freqs: Array, dur: float, vol := 0.5) -> AudioStreamWAV:
	# freqs 是一串频率,均分时间 -> 简易琶音
	var n := int(RATE * dur)
	var data := PackedByteArray(); data.resize(n * 2)
	var seg := max(1, n / freqs.size())
	for i in n:
		var fi: int = min(i / seg, freqs.size() - 1)
		var f: float = freqs[fi]
		var t := float(i) / RATE
		# 简单 ADSR 包络
		var env: float = clamp(1.0 - float(i) / n, 0.0, 1.0)
		var attack: float = clamp(i / 200.0, 0.0, 1.0)
		var s := sin(TAU * f * t) * env * attack * vol
		data.encode_s16(i * 2, int(clamp(s, -1.0, 1.0) * 32767))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = RATE
	st.stereo = false
	st.data = data
	return st

func _play(stream: AudioStreamWAV) -> void:
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.play()

func coin() -> void:   _play(_tone([880.0, 1320.0], 0.12, 0.4))
func jump() -> void:   _play(_tone([330.0, 520.0], 0.10, 0.35))
func win() -> void:    _play(_tone([523.0, 659.0, 784.0, 1047.0], 0.5, 0.45))
func lose() -> void:   _play(_tone([392.0, 311.0, 196.0], 0.5, 0.45))
