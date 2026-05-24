# Demo 13 — Particles (CPU + GPU)

鼠标 = 拖尾,左键 CPU 爆炸,右键 GPU 大爆炸。完整理解两种粒子节点的差异。

## 跑起来

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```

- 移动鼠标:Cursor 子节点 `Trail` (CPUParticles2D) 自动跟随
- 左键:`CPUParticles2D` 一次性爆炸 (~80 粒)
- 右键:`GPUParticles2D` 大爆炸 (~220 粒)
- **R** 清空当前所有爆炸

## 学到什么

### 1. CPU vs GPU,选哪个?
| 维度 | CPUParticles2D | GPUParticles2D |
|------|----------------|----------------|
| 计算位置 | CPU 每帧算每个粒子 | GPU shader 并行算 |
| 上限 | 100~1000 粒比较稳 | 上万粒不卡 |
| 配置 | 直接在节点 Inspector 改 | 必须配 `ParticleProcessMaterial` |
| 跨平台 | 哪都跑(gl_compatibility 也行) | 老 GLES 设备可能不支持高级特性 |
| 调试 | 可视化所见即所得 | shader 编译失败更隐蔽 |

经验:**少量、需要逻辑控制(命中/伤害判定)的 → CPU**;**大量装饰性的(烟雾、火焰、瀑布)→ GPU**。

### 2. 关键属性(两者通用名)
| 属性 | 作用 | 试试 |
|------|------|------|
| `amount` | 同时存在多少粒 | 200, 5000 |
| `lifetime` | 单粒生命(秒) | 0.5, 3.0 |
| `one_shot` | 是否一次性发完就停 | 爆炸=true,瀑布=false |
| `explosiveness` 0~1 | 0=均匀发,1=一帧内全发 | 爆炸=0.95 |
| `randomness` 0~1 | 各项参数的随机扰动 | 一般 0.3~0.6 |
| `emission_shape` | point/circle/rect/box | 不同形状的源 |
| `spread` (deg) | 喷射夹角,180=四面八方 | 火焰=15, 爆炸=180 |
| `direction` | 主方向向量 | 火 (0,-1),雨 (0,1) |
| `gravity` | 持续加速度 | (0, 200) 往下落 |
| `initial_velocity_min/max` | 出生速度范围 | 100~400 |
| `scale_amount_min/max` | 出生尺寸 | 1~5 |
| `color_ramp` | 生命曲线上的颜色变化 | 渐变 |

### 3. Gradient 渐变(颜色生命曲线)
```
[sub_resource type="Gradient" id="boom_grad"]
offsets = PackedFloat32Array(0, 0.4, 1)
colors = PackedColorArray(
    1, 1, 1, 1,         # offset 0.0 -> 白色不透明
    1, 0.6, 0.2, 1,     # offset 0.4 -> 橙不透明
    0.6, 0.1, 0.05, 0   # offset 1.0 -> 暗红透明
)
```
4 个浮点 = RGBA。颜色按粒子生命比例插值。**alpha 最后归 0** = 自然淡出。

CPUParticles2D 直接吃 `Gradient`;GPUParticles2D 的 `ParticleProcessMaterial.color_ramp` 吃 `GradientTexture1D`(把 Gradient 烘成 1D 纹理)。

### 4. CPU 模板复用的模式
本 demo 在 `.tscn` 里放了一个 `BoomTemplate` 节点(不可见,emitting=false)。每次点击:
```gdscript
var boom = boom_template.duplicate()
boom.position = pos
boom.emitting = true
explosions.add_child(boom)
get_tree().create_timer(lifetime + 0.2).timeout.connect(boom.queue_free)
```
**duplicate()** 比每次新建 + 手动 set 一堆参数省事得多。Inspector 里调好了,代码只管复制和触发。

### 5. GPU 粒子的"必须配 ProcessMaterial"
```gdscript
var p = GPUParticles2D.new()
var mat = ParticleProcessMaterial.new()
mat.emission_shape = ...
mat.direction = Vector3(0, -1, 0)   # 注意:3D 向量,即使 2D 用
mat.spread = 180.0
...
p.process_material = mat
```
- GPU 内部统一按 3D 算,所以 `direction`、`gravity` 等是 `Vector3`,即便挂在 2D 节点上 z 给 0
- 没 `texture` 时 GPU 粒子是看不见的 → 给个 1×1 白点

### 6. 拖尾 = "连续发射 + 跟随节点"
本 demo 的 Trail 挂在 Cursor 下:
- Cursor.position 每帧改 → Trail 跟着移动
- `emitting = true`, `one_shot = false`, `lifetime = 0.7` → 持续出粒
- 粒子出生后**走自己的速度,不跟 Cursor 跑** → 形成尾迹
- 把 `lifetime` 调大或 `initial_velocity_max` 调小,尾巴更长更"粘"

### 7. local_coords:粒子坐标系
默认 `local_coords = false`:粒子出生后用世界坐标,父节点动它们不动 → 拖尾。
`local_coords = true`:粒子跟父节点一起平移旋转 → 适合"挂在飞船尾部的火焰"。

## 改造练习

1. **加重力轨迹**:让爆炸的 `gravity` 提高到 (0, 500),粒子落得更快,有"碎屑回到地面"的感觉。
2. **环形发射**:把 `emission_shape` 改成 `EMISSION_SHAPE_RING_VOLUME` 或在 CPU 里改 `EMISSION_SHAPE_CIRCLE`,做"冲击波"。
3. **粒子贴图**:给 `texture` 上 32×32 的"火花" PNG,看效果质感跃升。试试 [Kenney Particle Pack](https://kenney.nl/assets/particle-pack)。
4. **吸引力**:让粒子被某点吸引 → CPU 加 `attractor` 节点(`GPUParticlesAttractor2D` 也有,GPU 才能感应)。
5. **加 SFX**:在 `_spawn_cpu_boom` 里同步播个低音 beep(参考 demo 09),爽度跃升。
6. **Pool**:别每次都 `duplicate + queue_free`,做一个 20 个的池,循环复用。点击 1000 次也不掉帧。

## 易踩坑

- GPUParticles2D 没贴图 → **完全看不到东西**。不是 bug,是默认渲染白色四边形需要采样纹理。
- `explosiveness = 1.0` 不发?**先 `emitting = false` 再 set 一次 `= true`,或者 `restart()`**。一次性粒子被"重新启动"才会再发一波。
- `one_shot = true` 的粒子发完后 `emitting` 自动变 false,需要再 set true 才能再发。
- `amount` 大时实际看到的粒子上限受 `lifetime` 影响:`amount` 是"最大并存数",发射速率 ≈ amount/lifetime。
- CPU 粒子在 `gl_compatibility` 上 gradient 的 RGB 是**线性空间**,看着可能偏暗。`color_ramp` 用更亮的颜色补偿。
- 不要在 `_process` 里每帧 `new GPUParticles2D() + new ParticleProcessMaterial()` —— GPU 材质编译有开销。复用或 pool。
