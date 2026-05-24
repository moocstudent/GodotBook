# Demo 10 — 3D Basics

第一个 3D 场景:相机、平行光、地面、可旋转 hero 立方,**A/D** 绕主立方公转、**W/S** 推拉镜头、**Space** 在随机位置砸下一个随机色立方。

## 跑起来

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```

## 学到什么

### 1. 2D vs 3D 节点继承体系
```
Node
├── Node2D          (有 position: Vector2)
│   └── Sprite2D / CharacterBody2D / ...
├── Node3D          (有 position: Vector3, rotation: Vector3)
│   └── MeshInstance3D / Camera3D / Light3D / CharacterBody3D / ...
└── Control         (UI,position/anchors)
```
**这三套并列**,不互通。你不会把 Sprite2D 放进 Node3D 期望它显示在 3D 世界里 —— 想做"3D 中的精灵"用 `Sprite3D` 节点。

### 2. 最小 3D 场景需要的东西
| 必备 | 节点 | 不放会怎样 |
|------|------|----------|
| 相机 | `Camera3D`,设 `current = true` | 漆黑一片 |
| 光照 | `DirectionalLight3D` 或环境光 | 黑色剪影 |
| 几何 | `MeshInstance3D` + Mesh + Material | 看不到东西 |

### 3. Mesh:几何形状
本 demo 用**两个内置 Mesh**:
- `PlaneMesh` — 一块矩形面片(常用做地面)
- `BoxMesh` — 立方体
其他内置:`SphereMesh`,`CylinderMesh`,`CapsuleMesh`,`TorusMesh`,`PrismMesh`,`QuadMesh`。

真实项目里你会:
- 从 `.glb`/`.gltf` 导入(Blender 直出)
- 或 `ArrayMesh.new()` + `SurfaceTool` 程序化构造

### 4. Material:外观
```gdscript
var mat := StandardMaterial3D.new()
mat.albedo_color = Color.from_hsv(randf(), 0.7, 0.95)
mat.metallic = 0.1
mat.roughness = 0.5
cube.material_override = mat
```
- `albedo_color` — 基础颜色(漫反射)
- `metallic` 0-1 — 金属感
- `roughness` 0-1 — 越大越漫反,越小越镜面
- `emission` — 自发光(LED 招牌效果)

Godot 4 采用 **PBR(基于物理的渲染)**,这套参数是行业通用语言(跟 Unreal/Blender 一致)。

`material_override` 给单个 MeshInstance 用,会覆盖 Mesh 自带 material。批量用同一材质改 Mesh 的 `surface_material_*`。

### 5. Transform3D 是怎么回事
```
transform = Transform3D(1, 0, 0,   0, 1, 0,   0, 0, 1,   x, y, z)
                       └── basis_x ──┘ basis_y └ basis_z └ origin
```
3D 节点的 `transform` 是个 `Transform3D`,= **3×3 旋转矩阵(三个基向量)+ 平移向量**。

但 99% 时间你只用便捷 API:
```gdscript
node.position = Vector3(1, 2, 3)
node.rotation = Vector3(0, PI/2, 0)         # 欧拉角(弧度)
node.rotate_y(delta * 1.2)                  # 局部 Y 轴转
node.look_at(target_pos, Vector3.UP)        # 朝向目标
```

### 6. 相机和 Pivot 套娃(轨道相机经典做法)
本 demo 的相机其实**不绕场景中心转,而是绕 Pivot 转**:
```
CamPivot (Node3D)     ← 旋转这个
└── Camera3D          ← 相机相对 Pivot 偏移在 (0, d*0.55, d)
```
要公转,只需:
```gdscript
pivot.rotate_y(delta * 1.4)
```
比手算"绕原点的 sin/cos 位置"直觉得多。这就是**层级 Transform** 的力量。

### 7. `look_at`
```gdscript
camera.look_at(pivot.global_position, Vector3.UP)
```
让相机的 -Z 轴(Godot 相机朝 -Z 看)指向目标,Up 向量保持稳定。**注意第二个参数**:全 0 或与目标方向共线会报警。

### 8. 内置渲染器对比
| 渲染后端 | 平台 | 用途 |
|---------|------|------|
| **Forward+** | 桌面 / 高端移动 | 全特效:GI、SSAO、SSR、Volumetric Fog |
| **Mobile** | 中端移动(Vulkan-mobile) | 删减部分高级特效,性能好 |
| **Compatibility(本 demo)** | 老 GL / WebGL | 兼容性最好,效果最简,移动通杀 |

切换:`Project Settings → Rendering → Renderer`。
本仓的 demo 全部锁了 **gl_compatibility**,符合"双端打包优先"的目标。

## 改造练习

1. **跟随相机**:让 Camera 跟 Hero,而不是固定 pivot。把 pivot 改成 Hero 的子节点,直接 `add_child(pivot)`。
2. **glTF 模型**:从 [Kenney 免费 3D 资源](https://kenney.nl/assets/3d-assets) 下一个 `.glb`,拖进项目,直接拖到场景,免费可商用。
3. **第一人称视角**:相机改成 Hero 子节点 + 鼠标 `Input.MOUSE_MODE_CAPTURED`,`_input` 里读 `event.relative` 旋转 Pivot/Camera。
4. **物理立方**:把生成出的 cube 改成 `RigidBody3D` + `CollisionShape3D`,Space 起就变成"砸方块"。
5. **环境**(WorldEnvironment 节点):加天空盒、雾、SSAO,场景档次跳一档。
6. **加点光源**:`OmniLight3D`,挂在 Hero 上,跟着它发光。

## 易踩坑

- 没看到任何东西 → **99% 是相机** `current = true` 没设,或者相机被几何挡了。
- 模型黑漆漆 → 没光源,或法线被翻反了(导入设置里勾 "Flip Faces")。
- `gl_compatibility` 下 **没有阴影 ShadowAtlas 调节项**,跟 Forward+ UI 不一样。
- `look_at(pos)` 在 pos 与节点重合时崩 —— 加距离判断或 try/catch(GDScript 没 try,用 `if pos.distance_to(global_position) < 0.01: return`)。
- 不要把 `MeshInstance3D` 缩放到负值,法线会反,光照看着诡异。
- **Y 轴是上**(Godot 3D 用 right-handed,Y-up,-Z forward),OpenGL 风。Unity 也是 Y-up;Unreal 是 Z-up。
