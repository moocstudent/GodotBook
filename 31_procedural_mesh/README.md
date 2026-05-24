# Demo 31 — Procedural Mesh (代码生成 3D 网格)

完全用代码生成 4 种网格:手搓立方体、UV 球、噪声星球、波浪地形。展示 Godot 两条程序化建模路:**SurfaceTool**(命令式)和 **ArrayMesh + PackedArray**(底层数组)。

## 跑起来

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```

- **1** 立方体(SurfaceTool 手搓 6 面)
- **2** UV 球(经纬度细分)
- **3** 噪声星球(球 + FastNoiseLite 位移)
- **4** 波浪地形(ArrayMesh 直接喂数组)
- 鼠标拖动旋转,滚轮缩放

## 学到什么

### 1. 网格的本质
一个 mesh = 几个 **PackedArray**:
| 数组 | 内容 |
|------|------|
| `ARRAY_VERTEX` | `PackedVector3Array` 顶点位置(必须) |
| `ARRAY_NORMAL` | 法线(影响光照) |
| `ARRAY_TEX_UV` | UV 坐标(贴图采样) |
| `ARRAY_COLOR` | 顶点颜色 |
| `ARRAY_INDEX` | `PackedInt32Array` 三角形索引(复用顶点) |
| `ARRAY_TANGENT` | 切线(法线贴图用) |

三角形 = 每 3 个顶点(或索引)一组,**逆时针**朝外(决定哪面是正面)。

### 2. 路 A:SurfaceTool(推荐入门)
命令式,像 OpenGL 立即模式:
```gdscript
var st := SurfaceTool.new()
st.begin(Mesh.PRIMITIVE_TRIANGLES)

st.set_uv(Vector2(0, 0))      # 设当前顶点的属性
st.add_vertex(Vector3(0, 0, 0))
st.set_uv(Vector2(1, 0))
st.add_vertex(Vector3(1, 0, 0))
st.set_uv(Vector2(0, 1))
st.add_vertex(Vector3(0, 1, 0))

st.generate_normals()         # 自动算法线!
st.generate_tangents()        # 自动算切线
var mesh := st.commit()       # → ArrayMesh
```
**优点**:`generate_normals()` 帮你算法线,不用手推叉乘。适合不规则形状。
**注意**:`set_*` 在 `add_vertex` **之前**调,设的是"接下来这个顶点"的属性。

### 3. 路 B:ArrayMesh 直接喂数组(最快)
```gdscript
var arrays := []
arrays.resize(Mesh.ARRAY_MAX)
arrays[Mesh.ARRAY_VERTEX] = verts        # PackedVector3Array
arrays[Mesh.ARRAY_NORMAL] = normals
arrays[Mesh.ARRAY_TEX_UV] = uvs
arrays[Mesh.ARRAY_INDEX] = indices       # PackedInt32Array

var mesh := ArrayMesh.new()
mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
```
**优点**:一次性提交,大网格(地形 64×64=4096 顶点)快得多。
**代价**:法线要自己算(本 demo 用相邻顶点叉乘)。

### 4. 索引(index)= 顶点复用
不用索引:每个三角 3 个顶点,共享的角重复存。
用索引:顶点存一次,三角用整数引用。
- 立方体:8 个角,12 个三角 → 不用索引 36 个顶点,用索引 8 个顶点 + 36 个索引
- 地形 64×64:省内存巨大,且 GPU 顶点缓存命中率高

```gdscript
# 一个 quad(两三角)的索引
indices.append(i); indices.append(i + grid); indices.append(i + 1)
indices.append(i + 1); indices.append(i + grid); indices.append(i + grid + 1)
```

### 5. UV 球的经纬度细分
```gdscript
for r in rings + 1:                      # 纬度 0..PI
    var phi := PI * r / rings
    for s in segments + 1:               # 经度 0..2PI
        var theta := TAU * s / segments
        var dir := Vector3(
            sin(phi) * cos(theta),
            cos(phi),
            sin(phi) * sin(theta)
        )
        verts.append(dir * radius)
```
- `phi` 从北极到南极,`theta` 绕一圈
- 单位方向 × 半径 = 球面点
- **极点处三角退化**(segments 个三角共顶点),这是 UV 球的固有缺陷;要均匀分布用 icosphere

### 6. 噪声位移 = 程序化星球/地形
```gdscript
var noise := FastNoiseLite.new()
noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
noise.frequency = 1.2

var rad := radius + noise.get_noise_3dv(dir * 2.0) * displace
```
**FastNoiseLite** 是 Godot 内置的噪声生成器(Perlin / Simplex / Cellular)。
- 球面:沿法线方向位移 → 山脉海洋
- 平面:位移 y → 起伏地形
- 多层叠加(fractal)→ 更自然(`fractal_octaves`)

### 7. 法线手算(叉乘)
```gdscript
var n := (right - here).cross(down - here).normalized()
```
两条边向量叉乘 = 垂直于面的方向 = 法线。
**方向要对**:叉乘顺序错了法线朝里,面会变黑(背光)。本 demo 检查 `n.y < 0` 翻转。

## 与 CSG(demo 21)的区别
| | CSG | Procedural Mesh |
|---|-----|-----------------|
| 方式 | 布尔运算拼基础体 | 直接定义每个顶点 |
| 控制力 | 粗(灰盒) | 细(逐顶点) |
| 性能 | 实时合并,慢 | 生成一次,静态,快 |
| 适合 | 关卡 blocking | 地形、星球、自定义形状 |

## 改造练习

1. **顶点上色**:`ARRAY_COLOR` 按高度给地形染色(水蓝→草绿→雪白),材质开 `vertex_color_use_as_albedo`。
2. **碰撞体**:`mesh.create_trimesh_shape()` 生成 ConcavePolygonShape3D,做可走的地形。
3. **Icosphere**:从正二十面体细分,顶点均匀(比 UV 球好),做行星 LOD。
4. **动态变形**:每帧改顶点 y(波浪),重 commit。或者直接用 vertex shader 改(更快)。
5. **Marching Cubes**:体素 → 平滑网格,做洞穴 / 软体。
6. **MultiMesh**:生成一个网格,用 MultiMeshInstance3D 画 10000 份(草、树),配 demo 26 的 GPU 思路。
7. **保存为 .res**:`ResourceSaver.save(mesh, "res://planet.res")`,运行时 preload,不每次生成。

## 易踩坑

- **三角绕向**:逆时针朝外。错了整个面朝内,从外面看是透明/黑的。调试时材质开 `cull_mode = Disabled` 看两面。
- **忘了法线** → 全黑或全亮。SurfaceTool 用 `generate_normals()`;ArrayMesh 自己算。
- `arrays.resize(Mesh.ARRAY_MAX)` 不做 → `add_surface_from_arrays` 崩。数组必须是 ARRAY_MAX 长度。
- 索引超出顶点数 → 崩或乱。地形的 `i + grid + 1` 在最后一行/列会越界,循环范围用 `grid - 1`。
- `FastNoiseLite` 默认 frequency=0.01,对小坐标几乎不变 → 看着平。调大 frequency 或放大输入坐标。
- 大网格(>65536 顶点)在某些平台索引用 16 位会溢出 → Godot 自动转 32 位,但要注意。
- 每帧重新生成大网格会卡 → 生成一次缓存,或只改 vertex buffer 不重建拓扑。
