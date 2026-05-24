# Demo 09 — Audio (Buses + SFX Pool, 0 素材)

完整音频架构,**不依赖任何 .wav/.ogg 素材**:所有声音都在 GDScript 里合成 PCM。展示三件事:
1. 自己生成 `AudioStreamWAV`(正弦波 + 信封)
2. **Audio Bus** 体系(Master / Music / SFX 分组调音)
3. **SFX 池**(多个 player 轮转,解决"打断自己"的经典问题)

## 跑起来

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```

- 三个 Beep 按钮 → SFX bus 上的不同音高
- **Rapid Fire**:按住,每 60ms 发一次,看 8 个 player 怎么轮转
- **Music ON/OFF**:Music bus 上的循环和弦
- 三条 dB 滑块独立控制各 bus

## 学到什么

### 1. 程序化合成 PCM
```gdscript
var stream := AudioStreamWAV.new()
stream.format = AudioStreamWAV.FORMAT_16_BITS
stream.mix_rate = 22050
stream.stereo = false
var data := PackedByteArray()
data.resize(samples * 2)
for i in samples:
    var s = sin(TAU * freq * t)
    var v = int(s * 32767)
    data[i*2]   = v & 0xFF
    data[i*2+1] = (v >> 8) & 0xFF
stream.data = data
```
要点:
- **format**:`FORMAT_8_BITS` / `FORMAT_16_BITS` / `FORMAT_IMA_ADPCM` 等
- **PackedByteArray**:16bit 用 2 字节,**little-endian**
- **TAU = 2π**:GDScript 内置,比 `2 * PI` 干净
- **信封**(attack/release):头尾不淡入淡出会有 "click" 爆音 —— 物理事实,不是代码 bug

### 2. 让它循环
```gdscript
stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
stream.loop_begin = 0
stream.loop_end = sample_count
```
循环点最好落在过零点,否则衔接处会"啪"一下。本 demo 用整数倍周期的长度自动避免。

### 3. Audio Bus 三层架构
```
[Master]   ← 全局总音量(主推子)
  ├── [Music]   ← BGM 走这里,玩家可以"只关音乐"
  └── [SFX]     ← 所有音效走这里
```

代码加 bus:
```gdscript
var i := AudioServer.bus_count
AudioServer.add_bus(i)
AudioServer.set_bus_name(i, "Music")
AudioServer.set_bus_send(i, "Master")  # 输出送回 Master
```

播放器声明所属 bus:
```gdscript
audio_player.bus = "Music"
```

设音量:
```gdscript
AudioServer.set_bus_volume_db(i, -6.0)
```

> **生产做法**:在编辑器底部 **Audio** 面板手动配 bus,保存为 `default_bus_layout.tres`。比代码加更直观。本 demo 用代码是为了 **0 素材** 自包含。

### 4. 为什么 dB 不是 0-100
人耳是对数感知:**-6 dB 听起来是一半**,-12 dB 是 1/4。线性 50% 听起来变化非常小。
- `0 dB` = 原音量
- `+6 dB` = 双倍能量(差不多双倍响度)
- `-80 dB` 接近静音
转换:`linear_to_db(0.5)` ≈ -6,`db_to_linear(-6)` ≈ 0.5

### 5. SFX 池:经典套路
```gdscript
const SFX_POOL_SIZE := 8
var _pool: Array[AudioStreamPlayer] = []

func _play_sfx(stream):
    for n in SFX_POOL_SIZE:
        var p = _pool[(idx + n) % SFX_POOL_SIZE]
        if not p.playing:
            p.stream = stream; p.play(); return
    # 全忙 -> 抢占最早的
```
**单个 AudioStreamPlayer 同时只能播一个声音** —— 重新 `play()` 会立刻打断前一次。鼓点、连发枪、走路脚步全部要池。

> 实际工程也常做成 Autoload 单例 `Sfx.play("hit")`,内部维护池 + 资源映射表。

### 6. 三种 AudioStreamPlayer
| 节点 | 用于 | 特性 |
|------|------|------|
| `AudioStreamPlayer` | UI 音效、BGM | 无定位,直接进 bus |
| `AudioStreamPlayer2D` | 2D 世界音效 | 按 position 衰减、左右声场 |
| `AudioStreamPlayer3D` | 3D 世界音效 | 立体衰减、HRTF、多普勒 |

本 demo 全用 1D 的,UI 场景嘛。

## 改造练习

1. **方波 / 锯齿波**:把 `sin(TAU*f*t)` 换成 `sign(sin(...))`(方波)或 `2*(t*f - floor(t*f+0.5))`(锯齿)。瞬间复古游戏机味。
2. **FM 合成**:用一个低频正弦去调制主频:`sin(TAU * (freq + mod_amp * sin(TAU * mod_freq * t)) * t)`。
3. **音高变化**:`audio_player.pitch_scale = 1.2` 改播放速度兼调音高。比生成 N 个 stream 省内存。
4. **Effect 链**:在 SFX bus 上加 `AudioEffectReverb` / `AudioEffectChorus`(编辑器 Audio 面板里加 → 立竿见影)。
5. **Bus Layout 资源**:Editor → Audio → Save As… → 选 `default_bus_layout.tres`,以后无需代码配 bus。
6. **从文件加载**:`load("res://hit.wav")` 返回 `AudioStreamWAV` / `AudioStreamOggVorbis`,直接 `player.stream = ...`。

## 易踩坑

- **AudioStreamWAV vs AudioStreamMP3 vs AudioStreamOggVorbis**:WAV 是 PCM,占空间但延迟为 0,适合短音效。BGM 用 OGG(MP3 受专利限制现已开源,但 OGG 更轻)。
- 16bit 采样 **不要忘了 little-endian**(低字节先),写反了听起来像噪音。
- `mix_rate` 必须和你算 `t = i/mix_rate` 时用的值一致,否则音高错位。
- `set_bus_volume_db` 的 bus 名传错会**静默不报错**,推荐传 index 而不是字符串。
- `pitch_scale = 0` 会让音频卡住不进度,不要这么用做暂停 —— 用 `stream_paused`。
- iOS / Android 的某些低端机 22050Hz 已经够用;别盲目 48000Hz 让初始化变慢。
