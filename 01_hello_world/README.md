# Demo 01 — Hello, Godot!

最小可运行项目。屏幕中央显示一段文字,按 **Esc** 退出。

## 跑起来

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```

第一次会让 Godot 编辑器导入项目;按 **F5** 运行。
或直接命令行运行主场景:
```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path . res://main.tscn
```

## 学到什么

### 1. 节点树
```
Main (Node2D)         ← 根节点,挂了 main.gd 脚本
├── Title (Label)     ← 显示标题
└── Hint  (Label)     ← 显示提示
```
**Node2D** 是 2D 世界的基础节点(有 `position`/`rotation`/`scale`)。**Label** 是 UI 控件(Control 派生),用 `text` 属性显示字符串。

### 2. 脚本生命周期
- `_ready()` — 节点和所有子节点都进入场景树后,**调用一次**。这里做初始化最稳。
- `_process(delta)` — 每帧调用,`delta` 是上一帧到现在的秒数(浮点)。
- `_physics_process(delta)` — 固定步长,默认 60Hz。**移动和碰撞写在这里**。
- `_unhandled_input(event)` — 没被任何 UI 控件消费的输入。Esc 退出常写这。

### 3. `@onready` 和 `$NodePath`
```gdscript
@onready var title: Label = $Title
```
等价于:
```gdscript
var title: Label
func _ready() -> void:
    title = get_node("Title")
```
`$X` 是 `get_node("X")` 的语法糖。`%X` 则需要节点开启 "Unique Name in Owner",更稳健。

### 4. `.tscn` 是文本
打开 `main.tscn` 看一眼 —— 它就是一段声明式文本:
```
[node name="Title" type="Label" parent="."]
text = "Hello, Godot!"
```
所以可以用任何文本编辑器(包括 AI)直接改场景,无需打开编辑器。

### 5. InputMap
`ui_cancel`、`ui_accept`、`ui_left/right/up/down` 都是项目默认就有的输入动作。
**Project → Project Settings → Input Map** 可以加自定义动作(下个 demo 会用到)。

## 想改造?试试这些

1. 把 `Title.text` 改成你的名字,运行验证。
2. 在 `_process(delta)` 里让 `title.position.x += 50 * delta`,做个滚动字幕。
3. 加一个 `_ready` 里的 `Engine.max_fps = 30` 看效果。
4. 把 `Hint` Label 删掉,然后把 `main.gd` 里 `hint.text = ...` 注释掉 —— 看 Godot 怎么报 `Null instance` 错误,理解 `@onready` 何时被解析。
