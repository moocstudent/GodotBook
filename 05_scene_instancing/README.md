# Demo 05 — Scene Instancing(子弹工厂)

把 `bullet.tscn` 当作"模板",运行时反复实例化。**这是 Godot 中所有"生成体"逻辑的范式**:子弹、敌人、粒子、UI 卡片、波数怪……都是同一招。

## 跑起来

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```

A/D 移动,Space 单发,Timer 每 0.4 秒自动发射一束三连。

## 学到什么

### 1. PackedScene = 场景模板
```gdscript
const BulletScene: PackedScene = preload("res://bullet.tscn")
```
- **PackedScene** 是 `.tscn` 文件被加载后在内存里的形式
- 一个 PackedScene 可被 `.instantiate()` **任意多次**,每次得到独立的节点树
- `preload`:编译期解析,常量,推荐用于"启动就要的"资源
- `load`:运行时解析,适合"按需"的资源(场景切换、大地图)

### 2. instantiate + add_child 二段走
```gdscript
var b := BulletScene.instantiate()    # 1. 拷贝出节点
b.position = muzzle.global_position   # 2. 设属性
bullets_parent.add_child(b)           # 3. 加进场景树 → 这一步之后 _process 才会跑
```
**只 instantiate 不 add_child 等于没加**,新人最容易卡这。

### 3. 容器节点 = "对象池"目录
```
Main
└── Bullets (Node2D)   ← 所有子弹都加到这里
    ├── Bullet
    ├── Bullet
    └── ...
```
好处:
- `bullets_parent.get_child_count()` 一行拿到活跃数量
- `for b in bullets_parent.get_children(): b.queue_free()` 清屏
- 不污染主场景结构

### 4. `queue_free()` vs `free()`
- `queue_free()`:**在本帧末尾**才真正销毁。安全,推荐。
- `free()`:立即销毁。如果当时还在被信号回调使用,**会崩**。

### 5. Marker2D = 锚点
`Muzzle` 是个 `Marker2D`(纯坐标节点,不渲染),挂在 Player 下作为"枪口位置"。
- 比硬编码 `position + Vector2(0,-20)` 直观
- Player 旋转、缩放时 Muzzle 跟着变,`global_position` 自动正确

### 6. Timer 自动开火
```
[node name="AutoFireTimer" type="Timer" parent="."]
wait_time = 0.4
autostart = true
```
+ 代码:
```gdscript
auto_timer.timeout.connect(_on_auto_fire)
```
不用自己在 `_process` 里维护 `_cooldown -= delta`。**Timer 节点已经替你写了**。

### 7. Area2D vs StaticBody2D vs CharacterBody2D
| 类型 | 物理碰撞 | 检测触发 | 用于 |
|------|---------|---------|------|
| `StaticBody2D` | ✓ 阻挡 | ✗ | 地面、墙 |
| `CharacterBody2D` | ✓ 阻挡 | ✗ | 玩家、敌人 |
| `Area2D` | ✗ 不阻挡 | ✓ `body_entered`/`area_entered` | **子弹、拾取物、伤害判定** |

子弹用 Area2D —— 不需要"撞墙弹开",只要"碰到敌人"被检测到。

## 改造练习

1. **碰撞造成伤害**:把敌人(再开一个场景)做成 CharacterBody2D + Area2D 子节点。在 `bullet.gd` 里:
   ```gdscript
   area_entered.connect(func(other): if other.is_in_group("enemies"): queue_free())
   ```
2. **加屏抖/闪光**:开火时 `camera.offset = Vector2(randf_range(-4,4), 0)`,Tween 回 0。
3. **对象池**:与其频繁 free+new,不如池化。预生成 50 个 bullet 隐藏,要发射就 show + reposition。
4. **散射模式**:把 `_on_auto_fire` 的三连改成 5 连扇形,体会"弹幕"如何来。
5. **链式爆炸**:子弹消失前生成一个粒子场景(`CPUParticles2D` 或自定义粒子节点)。

## 易踩坑

- `instantiate()` 出来的节点,**所有 @onready 字段都还没就绪**,直到 `add_child` 后下一帧才被 `_ready()` 调用。在 `_ready` 之前不要访问它的子节点。
- 别在 `_process` 里疯狂 `instantiate` 而不 `queue_free` —— 节点数会爆炸,FPS 雪崩。
- `Bullets` 容器节点本身**没有渲染**(Node2D 不画东西),所以哪怕里面有 1000 个 Bullet,容器自身也只是逻辑组织。
- `preload` 路径打错时**编辑器立刻报错**;`load` 路径打错运行时才报错。优先 preload。
