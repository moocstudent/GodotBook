# Demo 21 — 3D 第一人称 + CSG 关卡

CharacterBody3D + 鼠标控制视角 + CSG 程序化关卡(地板 + 四面墙 + 内墙 + 减法掏出的洞口 + 柱子 + 阶梯)。**0 美术资源**,整个 3D 世界都是 CSG 拼出来的。

## 跑起来

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```

- **WASD** 走,**鼠标** 看,**Space** 跳
- **ESC**:第一次释放鼠标(便于切窗口),第二次退出
- **左键**:重新抓回鼠标

## 学到什么

### 1. CSG 是什么
**Constructive Solid Geometry** = 用基础几何体的布尔运算搭建复杂形状。Godot 内置:
| 节点 | 操作 |
|------|------|
| `CSGBox3D` / `CSGSphere3D` / `CSGCylinder3D` / `CSGTorus3D` / `CSGPolygon3D` | 基础体 |
| `CSGCombiner3D` | 容器,把子节点合并 |
| `CSGMesh3D` | 把任意 Mesh 当成 CSG 输入 |

每个 CSG 子节点都有 `operation` 属性:
- `0 = Union` 加
- `1 = Intersection` 交
- `2 = Subtraction` 减

本 demo 在 `InnerWall` 内:一个 Wall Box + 一个 `operation=2` 的小 Box 减出洞口 = 门。

### 2. CSG 不是为最终游戏设计的
官方文档明确:**CSG 是 "blocking-out"(占位灰盒)工具**,不是发版几何。理由:
- CPU 每帧重新合并(实时计算 BSP)
- 几何质量低于手工建模
- UV 不可控

**实战流程**:用 CSG 快速搭关卡 → 用 Blender 重做发布版几何 → 替换。或者一旦 CSG 满意,**在编辑器里选中 CSGCombiner3D → Mesh Menu → Create MeshInstance3D**,bake 成静态 mesh + collision。

### 3. CSGCombiner3D 的 use_collision
```
[node name="Level" type="CSGCombiner3D"]
use_collision = true
```
开 = 自动从合并后的几何生成 `ConcavePolygonShape3D` 碰撞,玩家可以撞墙、站台阶。

### 4. CharacterBody3D 移动模板(行业标准)
```gdscript
func _physics_process(delta):
    # 1) 重力
    if not is_on_floor():
        velocity.y -= gravity * delta
    
    # 2) 跳跃
    if Input.is_action_just_pressed("jump") and is_on_floor():
        velocity.y = jump_velocity
    
    # 3) WASD → 局部方向
    var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var dir = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    
    velocity.x = dir.x * move_speed
    velocity.z = dir.z * move_speed
    
    move_and_slide()
```

`transform.basis * Vector3(x, 0, z)`:把"角色坐标系下的方向"转到"世界坐标系",所以无论身体朝哪 W 都是"向前"。

### 5. 第一人称相机的 yaw / pitch 分离
为什么不直接 `rotate(Vector3(rel.y, rel.x, 0))`?**因为会带来 roll**(歪头)。FP 相机的正确做法:
```
Player (CharacterBody3D)      ← yaw 在身体上(绕 Y)
└── CamPivot (Node3D)         ← pitch 在 pivot 上(绕 X)
    └── Camera3D
```
```gdscript
rotate_y(-rel.x * sens)               # 身体左右
cam_pivot.rotate_x(-rel.y * sens)     # 相机上下
cam_pivot.rotation.x = clamp(..., -1.4, 1.4)   # 防止仰头到天上去
```

### 6. 鼠标模式
```gdscript
Input.mouse_mode = Input.MOUSE_MODE_CAPTURED   # 隐藏 + 锁定中心 + InputEventMouseMotion.relative 持续给
Input.mouse_mode = Input.MOUSE_MODE_VISIBLE     # 正常
Input.mouse_mode = Input.MOUSE_MODE_HIDDEN      # 隐藏但不锁
Input.mouse_mode = Input.MOUSE_MODE_CONFINED    # 锁在窗口内但可见
```
ESC 要给用户**逃出**鼠标锁定的方式,不然玩家切窗口都难。

### 7. 阶梯的处理
本 demo 用三个矮 box 错位模拟阶梯。CharacterBody3D 上有 `floor_max_angle`(默认 45°),阶梯如果太高(单步 > 0.5m)会被当成墙撞死。
**正确做法**:
- 单步高 ≤ 玩家 collider 半径
- 或开 `floor_snap_length` 让玩家"贴地"自动找平
- 或在阶梯前面放斜坡 collision(视觉是阶梯,物理是斜面)

## 改造练习

1. **冲刺**:按住 Shift `move_speed *= 1.8`。
2. **下蹲**:按 Ctrl 把 `CamPivot.position.y` Tween 到 0.3,Collider 高度同步变小。
3. **二段跳**:维护 `_jumps_left = 2`,着地复位。
4. **武器**:CamPivot 下加一个低 poly 武器 MeshInstance3D,跟随相机移动。开火用 `RayCast3D` 检测命中。
5. **关卡转 Mesh**:运行时不变,但发布前 CSGCombiner3D 选 "Bake Mesh Instance",删 CSG 节点,只留 MeshInstance3D + StaticBody3D。FPS 提升一倍。
6. **天空替换**:WorldEnvironment 的 `sky.sky_material` 换成 `PanoramaSkyMaterial`,贴一张 HDR 全景图。

## 易踩坑

- CSG 在 gl_compatibility 下**没问题**,但**子节点很多时性能急剧下降**。20 个 CSG 子节点是上限,超了就 bake。
- `move_and_slide` 内部已乘 delta,**不要再乘**。
- 相机的 pitch 不 clamp → 头顶倒过来,玩家 disorient,容易吐。-1.4~1.4 是常用区间(约 ±80°)。
- 鼠标 capture 模式下,**第一帧的 `event.relative` 可能很大**(从中心拽到鼠标位置)→ 视角猛甩。可以在第一次 capture 后跳过一帧。
- 阶梯 collision 卡住:试试 `floor_snap_length = 0.3`(默认 0.1),允许玩家"吸"在地面上。
- 没看到 CSG?CSGCombiner3D 的 `operation = subtraction` 会把整个东西"减"了 —— 父 Combiner 的 operation 默认是 union(0)。
- `Input.mouse_mode` 在 web export 上**必须由用户手势触发**才能 capture(浏览器限制)。
