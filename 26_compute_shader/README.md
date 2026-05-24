# Demo 26 — Compute Shader (RenderingDevice GPGPU)

在 GPU 上跑经典 **boids 群体模拟**(分离/对齐/凝聚)。512 个个体默认,`+/-` 调数量,`C` 切 CPU/GPU 对比 —— GPU 几千个不卡,CPU 几百个就掉帧。

> **注意**:计算着色器需要 **Forward+ 或 Mobile 渲染器**(Vulkan),`gl_compatibility` 不支持。本 demo 的 `project.godot` 特意设 `forward_plus`。代码里有 CPU fallback,创建 RenderingDevice 失败会自动降级。

## 跑起来

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```

## 学到什么

### 1. Compute Shader vs 普通 Shader
| | Fragment/Vertex shader | Compute shader |
|---|---|---|
| 触发 | 渲染管线自动跑 | 你手动 `dispatch` |
| 输入/输出 | 顶点 / 像素 | 任意 buffer(SSBO) |
| 用途 | 画东西 | **通用并行计算**(GPGPU) |
| 典型 | 着色、后处理 | 物理、粒子、boids、流体、图像处理 |

Compute shader = "把 GPU 当成几千核的并行 CPU 用"。

### 2. RenderingDevice = 底层图形 API
Godot 4 暴露的 Vulkan 抽象层。Compute shader 必须走它(没有高层 wrapper):
```gdscript
var rd := RenderingServer.create_local_rendering_device()
```
- **local** RenderingDevice 与主渲染分离,互不干扰
- 也可以用 `RenderingServer.get_rendering_device()` 拿主设备(想把结果直接喂渲染时用)

### 3. 完整流程(6 步)
```gdscript
# 1) 设备
var rd = RenderingServer.create_local_rendering_device()

# 2) 编译 shader
var shader_file: RDShaderFile = load("res://boids.glsl")
var spirv = shader_file.get_spirv()
var shader = rd.shader_create_from_spirv(spirv)
var pipeline = rd.compute_pipeline_create(shader)

# 3) 数据进 SSBO
var bytes = data.to_byte_array()
var buffer = rd.storage_buffer_create(bytes.size(), bytes)

# 4) 绑定 uniform set
var u = RDUniform.new()
u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
u.binding = 0
u.add_id(buffer)
var uniform_set = rd.uniform_set_create([u], shader, 0)

# 5) dispatch
var cl = rd.compute_list_begin()
rd.compute_list_bind_compute_pipeline(cl, pipeline)
rd.compute_list_bind_uniform_set(cl, uniform_set, 0)
rd.compute_list_dispatch(cl, groups, 1, 1)
rd.compute_list_end()
rd.submit()
rd.sync()

# 6) 读回(可选)
var out = rd.buffer_get_data(buffer).to_float32_array()
```

### 4. GLSL 计算着色器结构
```glsl
#[compute]                          // Godot 标记:这是 compute stage
#version 450

layout(local_size_x = 64) in;       // 每工作组 64 线程

layout(set = 0, binding = 0, std430) restrict buffer BoidBuffer {
    float data[];                   // 变长数组,跑在 GPU 上
} boids;

void main() {
    uint i = gl_GlobalInvocationID.x;   // 我是第几个线程
    if (i >= n) return;                 // 边界检查(线程总数会向上取整)
    // ... 处理 boids.data[i] ...
}
```

### 5. 工作组(workgroup)与 dispatch
- `local_size_x = 64`:**每个工作组** 64 个线程(GPU 一次调度的最小单位,通常 32/64)
- `dispatch(groups, 1, 1)`:启动 `groups` 个工作组
- 总线程 = `groups * 64`,所以 `groups = ceil(boid_count / 64)`
- 总线程会**多于** boid_count → shader 里必须 `if (i >= n) return`

### 6. std430 内存布局
SSBO 的内存对齐规则。坑点:
- `float` 4 字节,`vec2` 8 字节,`vec3` **按 16 字节对齐**(不是 12!)
- 本 demo 用纯 `float data[]` 数组,手动按 `i*4+0/1/2/3` 索引,**避开 vec3 对齐陷阱**
- param buffer 凑了 12 个 float(含 padding)对齐到 16 的倍数

### 7. 同步读回是性能杀手
```gdscript
rd.sync()                              # 阻塞等 GPU
var out = rd.buffer_get_data(buffer)   # GPU → CPU 拷贝,慢
```
本 demo 为了用 GDScript `draw_polygon` 可视化,**每帧读回** —— 这抵消了大部分 GPU 优势。

**真实做法**:让 compute 结果直接当渲染 shader 的输入(buffer 不离开 GPU)。例如:
- compute 写顶点 buffer → MultiMesh 渲染读同一 buffer
- compute 写纹理 → fragment shader 采样

## GPU vs CPU 实测(按 C 切换体感)
- CPU:O(n²),512 个就明显掉帧,1024 个卡成幻灯片
- GPU:512 个丝滑,2048 个仍流畅(瓶颈在读回不在计算)

boids 是 O(n²) 的天然并行问题 —— 每个个体独立算,完美适合 GPU。

## 改造练习

1. **去掉读回**:用 `MultiMeshInstance2D`,compute 直接写 multimesh 的 transform buffer,0 CPU 回传。需要用主 RenderingDevice。
2. **空间网格加速**:O(n²) → O(n)。把屏幕分格,boid 只查同格+邻格。compute shader 里实现 spatial hashing。
3. **鼠标吸引/排斥**:param buffer 加 `mouse_pos`,shader 里加一个朝鼠标的力。
4. **3D boids**:数据扩成 vec3(注意 std430 对齐!),渲染用 MultiMeshInstance3D。
5. **流体 / 烟雾**:同样的 RenderingDevice 框架,shader 换成 Navier-Stokes 或 SPH。
6. **图像处理**:buffer 换成 texture,做高斯模糊 / 边缘检测的 compute 版,比 CPU 快百倍。

## 易踩坑

- **gl_compatibility 渲染器不支持 compute** → `create_local_rendering_device` 返回 null。本 demo 用 forward_plus。
- `#[compute]` 标记和 `#version 450` 缺一不可,否则 SPIRV 编译失败。
- `local_size_x` 改了,GDScript 里 `groups` 计算的除数也要同步改。
- 总线程数 > 数据量,**漏写 `if (i >= n) return`** → 越界读写,结果乱或崩。
- std430 里用 `vec3` 不知道它占 16 字节 → 数据错位,这是 GPGPU 第一大坑。用 float 数组或 vec4 规避。
- `buffer_get_data` 在 `sync()` 之前调 → 读到旧数据或空。
- RID 资源(shader/pipeline/buffer/uniform_set)**必须手动 `rd.free_rid()`**,否则显存泄漏。本 demo 在 `_exit_tree` 和 resize 时清理。
- `submit()` + `sync()` 每帧调有开销;真要快用多缓冲 + fence,不每帧 sync。
