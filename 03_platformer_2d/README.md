# Demo 03 — Platformer 2D

经典 2D 平台跳跃骨架。A/D 移动,Space/W 跳跃。还实现了两个让手感不"硬"的小技巧:**土狼时间**和**跳跃缓冲**。

## 跑起来

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```

## 学到什么

### 1. 三种 2D 物理体的区别(必须分清)

| 类型 | 谁动它 | 用途 |
|------|--------|------|
| `StaticBody2D` | 不动 | 地面、墙、固定平台 |
| `CharacterBody2D` | 你写代码控制 `velocity` + `move_and_slide()` | 玩家、敌人(常用) |
| `RigidBody2D` | 物理引擎模拟(力/速度/扭矩) | 弹球、堆叠箱子 |

本 demo:**地面是 StaticBody2D,玩家是 CharacterBody2D**。

### 2. 节点结构
```
Player (CharacterBody2D)
├── PlayerCollider (CollisionShape2D, 矩形 40x60)
└── PlayerVisual  (ColorRect, 视觉)
```
**碰撞体 ≠ 视觉**。CollisionShape2D 决定物理形状,ColorRect / Sprite2D 决定看到的样子。新手常把它们混在一起,导致角色"看着小,撞得大"。

### 3. `_physics_process` + `velocity` + `move_and_slide`
```gdscript
velocity.y += gravity * delta   # 加速度
move_and_slide()                # 执行移动并处理碰撞
```
`move_and_slide()` 是 CharacterBody2D 的**核心方法**:
- 读 `self.velocity`
- 沿速度方向扫描碰撞
- 沿碰撞面"滑动"(不卡墙)
- 自动设置 `is_on_floor()` / `is_on_wall()` / `is_on_ceiling()`

### 4. 重力 + 终极下落速度
```gdscript
velocity.y = min(velocity.y + gravity * delta, max_fall_speed)
```
不夹一个上限的话,长时间下落会无限加速,穿过薄地面(隧穿)。

### 5. 土狼时间(Coyote Time)
玩家离开平台边缘的瞬间,大脑反应有延迟。给 100ms 的"宽容期",离地后仍能起跳:
```gdscript
if is_on_floor(): _coyote_timer = coyote_time
else: _coyote_timer -= delta
...
var can_jump = is_on_floor() or _coyote_timer > 0.0
```
没有这个的平台游戏会被骂"手感僵"。Celeste 用 6 帧,Hollow Knight 用 5 帧。

### 6. 跳跃缓冲(Jump Buffer)
玩家提前按跳,但还没落地。记录一下"按过",落地后立刻消费:
```gdscript
if Input.is_action_just_pressed("jump"): _jump_buffer_timer = jump_buffer_time
```
和土狼时间配合,让连续跳跃流畅自然。

### 7. `is_action_just_pressed` vs `is_action_pressed`
- `just_pressed`:**这一帧**按下沿(只触发一次)。跳跃、射击用它。
- `pressed`:**当前是不是按着**(连续帧都 true)。移动用它(`get_axis` 内部就用 pressed)。

## 改造练习

1. **二段跳**:加一个 `var _jumps_left = 2`,起跳时 -1,落地复位。
2. **可变高跳**:松开跳键时若 `velocity.y < 0`,把 `velocity.y *= 0.5`,这样按越久跳越高。
3. **加速/减速**:别直接 `velocity.x = ...`,用 `velocity.x = lerp(velocity.x, target, 0.2)`,有惯性。
4. **死亡区**:在屏幕底加一个 Area2D,玩家进入就 `position = Vector2(120, 500)` 复位。
5. **可移动平台**:把 Block 换成 `AnimatableBody2D`,加一个 Tween 让它来回移动。

## 易踩坑

- **移动一定写在 `_physics_process`,不要写在 `_process`**。前者步长固定,后者跟帧率走,会抖动 / 穿墙。
- 物理体的 `Transform2D.scale` 改了会扭曲碰撞体,**不要缩放 CharacterBody2D**,改 CollisionShape2D 的 `shape.size`。
- 默认 `floor_max_angle = 45°`,斜坡超过 45° 会被判成墙,角色会"卡住"。在 Inspector 里调。
- `move_and_slide()` 内部已用 `delta`,你**不要再乘 delta** 给 velocity(这是版本变迁后最常见的迷惑)。
