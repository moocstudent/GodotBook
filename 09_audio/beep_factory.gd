extends RefCounted
class_name BeepFactory

# 在内存里合成一段正弦波,打包成 AudioStreamWAV(16bit 单声道 PCM)。
# 不依赖任何 .wav/.ogg 素材,demo 自给自足。
#
# 信封:头尾各做一段线性淡入/淡出,避免开始/结束 "click" 爆音。
static func sine_beep(
		freq_hz: float,
		duration_s: float,
		sample_rate: int = 22050,
		volume: float = 0.5) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false

	var sample_count: int = int(duration_s * sample_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)            # 每个 16bit sample 占 2 字节

	var attack_s := 0.02                      # 20ms 淡入
	var release_s := 0.06                     # 60ms 淡出
	var attack_n := int(attack_s * sample_rate)
	var release_n := int(release_s * sample_rate)

	for i in sample_count:
		var t: float = float(i) / sample_rate
		# 信封 envelope:0->1->1->0
		var env := 1.0
		if i < attack_n:
			env = float(i) / attack_n
		elif i > sample_count - release_n:
			env = float(sample_count - i) / release_n
		var s: float = sin(TAU * freq_hz * t) * env * volume
		var v_int: int = clampi(int(s * 32767.0), -32768, 32767)
		# 16bit little-endian
		data[i * 2]     = v_int & 0xFF
		data[i * 2 + 1] = (v_int >> 8) & 0xFF

	stream.data = data
	return stream

# 简易"音乐":一个无限循环的和弦(三个正弦叠加)。
static func looping_chord(
		freqs: PackedFloat32Array,
		duration_s: float,
		sample_rate: int = 22050,
		volume: float = 0.2) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0

	var sample_count: int = int(duration_s * sample_rate)
	stream.loop_end = sample_count

	var data := PackedByteArray()
	data.resize(sample_count * 2)

	for i in sample_count:
		var t: float = float(i) / sample_rate
		var s := 0.0
		for f in freqs:
			s += sin(TAU * f * t)
		s = s / freqs.size() * volume
		var v_int: int = clampi(int(s * 32767.0), -32768, 32767)
		data[i * 2]     = v_int & 0xFF
		data[i * 2 + 1] = (v_int >> 8) & 0xFF

	stream.data = data
	return stream
