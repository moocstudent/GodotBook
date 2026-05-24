# Demo 34 — Fluid (CPU 2D SPH)

简化的 **SPH 流体**(光滑粒子流体动力学):~420 个粒子在重力下流动、堆积、晃荡。左键灌水搅动,右键排斥。空间哈希网格把邻居查找从 O(n²) 降到接近 O(n)。

## 跑起来

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```

- **左键按住**:把附近粒子推向鼠标(灌水 / 搅动)
- **右键按住**:排斥(炸开)
- **R** 重置,**+/-** 改粒子数

## 学到什么

### 1. SPH 的核心思想
把流体离散成一堆粒子,每个粒子代表一小团液体。流体的连续场(密度、压力)通过"**核函数**"(kernel)对邻居加权求和近似:
```
密度 ρᵢ = Σⱼ mⱼ · W(rᵢⱼ, h)
```
- `W` 是核函数,距离越近权重越大,超过光滑半径 `h` 为 0
- `h` = 粒子的"作用范围"

### 2. 每帧三步
```gdscript
_build_grid()                    # 1. 空间哈希(邻居加速)
_compute_density_pressure()      # 2. 算密度 → 压力
_compute_forces_and_integrate()  # 3. 压力梯度力 + 粘性力 → 积分位置
```

### 3. 密度 → 压力(不可压缩性)
```gdscript
dens[i] = Σ neighbor MASS * (h²-r²)³        # Poly6 核
pres[i] = STIFFNESS * (dens[i] - REST_DENSITY)
```
- 粒子挤在一起 → 密度高 → 压力高
- 压力梯度把粒子从高压推向低压 → **抵抗压缩**,这就是"液体不可压缩"的来源
- `STIFFNESS` 越大越"硬"(更不可压),但太大数值不稳定要更小步长

### 4. 两种力
```gdscript
# 压力力(Spiky 核梯度):互相推开
f_press += -dir * (pres[i] + pres[j]) * 0.5 * (h-dist)² / dens[j]

# 粘性力:速度趋同(液体的"黏稠")
f_visc += (vel[j] - vel[i]) * (h-dist) / dens[j]
```
压力让流体有体积、不塌缩;粘性让它流动平滑、不像气体乱飞。

### 5. 空间哈希网格(性能关键)
朴素 SPH 每个粒子查所有其他粒子 = O(n²)。900 个粒子 = 81 万次/帧,卡。

把空间分成 `h × h` 的格子,粒子按位置塞进格子:
```gdscript
func _build_grid():
    grid.clear()
    for i in count:
        grid[_cell_key(pos[i])].append(i)

func _neighbors(p):
    # 只查 3×3 = 9 个邻格(因为作用半径 = h = cell size)
    for dy in [-1,0,1]: for dx in [-1,0,1]:
        out += grid[cell + (dx,dy)]
```
作用半径 = 格子大小 → 邻居一定在 3×3 格内 → **O(n)**。这是所有粒子系统(流体、碰撞、boids)的标准加速结构。

### 6. 固定步长 + clamp
```gdscript
var dt = min(delta, 1.0/60.0)
```
SPH 对步长敏感,卡顿时 `delta` 突然变大会让粒子"爆炸"飞出屏幕。clamp 住上限。真正严谨要做**子步**(把一帧分几次小步算)。

### 7. 边界反弹
```gdscript
if p.x < pad: p.x = pad; v.x = abs(v.x) * DAMPING
```
碰墙:位置拉回 + 速度反向 + 乘阻尼(损失能量,不然永远弹)。

## CPU vs GPU
本 demo 是 **CPU 版**(GDScript),~420 粒子流畅,900 个开始吃力。要上几千上万:把这套搬到 **demo 26 的 compute shader 框架**:
- 密度/压力/力的循环 → compute shader
- 空间哈希 → GPU 上用前缀和(prefix sum)排序
工业级流体(如 Nvidia FleX)都是 GPU 的。

## 改造练习

1. **表面张力**:加一个让粒子聚团的力(颜色场梯度),水会形成水滴。
2. **元球渲染(metaballs)**:别画圆点,用 shader 把密度场渲染成光滑液面(SCREEN_TEXTURE + 阈值)。
3. **多相流**:两种"密度"的粒子(油+水),不互溶分层。
4. **障碍碰撞**:加静态圆/方,粒子绕流。
5. **GPU 化**:整套搬到 compute shader(demo 26),粒子数 ×20。
6. **交互浮力**:扔个刚体(RigidBody2D)进去,根据浸没粒子数施加浮力。

## 易踩坑

- **数值爆炸**:STIFFNESS 太大 / 步长太大 → 粒子瞬间飞散。调小 STIFFNESS 或减 dt。
- **粒子穿墙**:速度太快一帧跨过边界。边界检测 + clamp 位置(本 demo 做了)。
- O(n²) 忘了空间哈希 → 几百个就卡死。网格是必须的。
- 核函数系数(`0.000004` 等)是**经验调参**,不同 H / MASS / 粒子密度要重调,不是物理精确值。这个 demo 追求"看着像水"而非物理正确。
- `_physics_process` 跑模拟(固定步长),`_draw` 只渲染。别把模拟写 `_process`(帧率不稳)。
- Dictionary 当空间哈希,key 用 `Vector2i`(可哈希)。用 `Vector2`(float)当 key 会因精度问题命中率低。
