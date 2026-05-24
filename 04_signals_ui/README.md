# Demo 04 — Signals & UI

一个点击计数器。展示 Godot 的核心通信机制:**signal**(发布订阅)。

## 跑起来

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```

## 学到什么

### 1. UI 节点的根:Control
- **Node2D 用于游戏世界**(有 position,自由摆放)
- **Control 用于 UI**(有 layout / anchor / margin,自动布局)
- 弹窗、菜单、HUD 都应该挂在 Control 树下

### 2. 容器:VBoxContainer / HBoxContainer
- Container 节点会自动给子节点摆放位置和大小
- VBoxContainer:垂直堆叠;HBoxContainer:水平堆叠
- `theme_override_constants/separation`:子项间距
- `alignment = 1`:居中

不要手动 set 子节点位置 —— 让容器管;改不出效果的常见原因是子节点 `layout_mode` 不是 2(Anchors/Container 模式)。

### 3. 信号(signal):Godot 的核心通信
**内置信号**(节点自带):
```gdscript
plus_button.pressed.connect(_on_plus_pressed)
#         ^^^^^^^^ Button 自带的 signal
```

**自定义信号**:
```gdscript
signal count_changed(new_value: int)
signal milestone_reached(value: int)
...
count_changed.emit(count)        # 发射
count_changed.connect(handler)   # 订阅
```

类比:
- JS `EventEmitter.on() / emit()`
- Qt signal / slot
- C# `event Action<T>`

### 4. 两种连接方式

| 方式 | 写法 | 优劣 |
|------|------|------|
| **代码连接(推荐)** | `btn.pressed.connect(_on_press)` | 静态可见,容易重构,AI 可读 |
| **编辑器连接** | 选中节点 → Node 面板 → Signals 双击 | 直观但藏在 .tscn 里,容易丢 |

本 demo 全部用代码连接,所以打开 `main.gd` 就能看清所有事件流。

### 5. setter / getter
```gdscript
var count: int = 0:
	set(value):
		count = value
		count_label.text = str(count)
		count_changed.emit(count)
```
**赋值即触发副作用**。`count += 1` 会自动更新 UI 并发射信号 —— 你的业务代码只关心 `count`,UI 自己跟着变。
类比:Vue computed/ref、Swift `didSet`。

### 6. `%UniqueName` 语法
```gdscript
@onready var count_label: Label = %CountLabel
```
在 `.tscn` 里给节点开 `unique_name_in_owner = true`,就能用 `%名字` 从根节点直接取到,**不依赖路径**。重构节点树时不会断。

比 `$VBox/CountLabel` 这种相对路径稳得多。

## 改造练习

1. **加一个 ×2 按钮**:`count *= 2`。注意 setter 会再次触发副作用,自然就更新了。
2. **数值带颜色**:在 setter 里 `count_label.modulate = Color.GREEN if count >= 0 else Color.RED`。
3. **Tween 数字动画**:点 +1 时把 Label 缩放从 1.3 弹到 1.0:
   ```gdscript
   var t = create_tween()
   count_label.scale = Vector2(1.3, 1.3)
   t.tween_property(count_label, "scale", Vector2.ONE, 0.15)
   ```
4. **解耦成两个节点**:计数逻辑放在一个 Autoload(单例),UI 只订阅 `count_changed`。这是中大型项目的标准做法。
5. **撤销栈**:每次 set 时 `_history.append(old)`,加 Undo 按钮。

## 易踩坑

- 信号 `.connect()` 不会去重 —— 重复 connect 同一个 handler,会被调用多次。需要重连时用 `disconnect()` 或 `is_connected()` 判断。
- 信号传参数量和类型必须匹配 emit,**多一个少一个都会运行时报错**。
- `Control.layout_mode = 1` 是 anchors 模式,`= 2` 是 container 模式。子节点放进容器后会自动切到 2。
- `theme_override_*` 是单个控件覆盖主题样式;真正大量复用应做一个 Theme 资源。
