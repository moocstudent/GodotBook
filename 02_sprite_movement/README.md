# Demo 02 — Sprite Movement

WASD / 方向键控制一个笑脸移动,Shift 加速。

## 跑起来

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```

## 学到什么

### 1. 自定义 InputMap
打开 `project.godot` 翻到 `[input]` 段,看到 `move_left / move_right / move_up / move_down` 四个动作,各自绑定了两个 `InputEventKey`(WASD 和方向键)。

**等价的编辑器操作**:Project → Project Settings → Input Map → 添加 action → Add Event。

### 2. `Input.get_vector(...)`
```gdscript
var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
```
- 返回 `Vector2`,坐标系跟 Godot 屏幕一致(x 右正、y 下正)
- **自动归一化**:斜向 (1, 1) 会被压成 (0.707, 0.707),不会比直走快
- 比手写 `is_action_pressed` 四次再 normalize 简洁

也有 `Input.get_axis("neg", "pos")` 返回单浮点,适合一维输入。

### 3. `delta` 的重要性
```gdscript
position += dir * speed * delta
```
- `_process(delta)` 的 `delta` ≈ 上一帧用了多少秒(60fps 时约 0.0167)
- 不乘 delta 的话,游戏在不同帧率下移动速度不一样,**这是新人最常见的 bug**
- 涉及物理/碰撞应改用 `_physics_process(delta)`(下一个 demo 会用)

### 4. `@export` 暴露字段
```gdscript
@export var speed: float = 300.0
```
在场景里选中 Player 节点,**Inspector 右侧**就能直接改 speed,不用动代码。
类比:Unity `[SerializeField]`、Unreal `UPROPERTY(EditAnywhere)`。

### 5. 视口尺寸 clamp
```gdscript
var vp := get_viewport_rect().size
position.x = clamp(position.x, 0.0, vp.x)
```
`get_viewport_rect()` 返回当前视口矩形;`clamp` 是 GDScript 内置全局函数。

## 改造练习

1. **改速度**:Inspector 里把 `speed` 改成 600,运行看差别。
2. **加旋转**:`rotation += delta * 2`,Sprite 会转。
3. **鼠标朝向**:`look_at(get_global_mouse_position())`,Sprite 永远看鼠标。
4. **网格对齐移动**:把 `position += ...` 改成按格(比如 32px)瞬移,实现 roguelike 风格。
5. **加摩擦**:别直接 `position +=`,先维护一个 `velocity`,按 `lerp(velocity, target, 0.1)` 缓动。

## 易踩坑

- `physical_keycode` vs `keycode`:前者按物理键位(QWERTY 布局上的 W),后者按当前键盘布局映射后的字符。游戏一般用 **physical_keycode**,这样法语 AZERTY 键盘也能正确触发 "W"。
- `_process` vs `_physics_process`:用了物理体(CharacterBody2D 等)就一定用 `_physics_process`,否则会抖动。
