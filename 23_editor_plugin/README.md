# Demo 23 — Editor Plugin

完整 EditorPlugin 例子。在编辑器里多出:
1. **左下角 Dock**:Scene Stats(节点统计)+ Notes(每项目笔记 auto-save)
2. **Project → Tools 菜单**:`GodotStuff: Reset Notes`

## 安装(本 demo 已自动启用)

`project.godot` 里加这一段就自动启用:
```ini
[editor_plugins]
enabled=PackedStringArray("res://addons/godotstuff_dock/plugin.cfg")
```

或者:Project → Project Settings → **Plugins** → 把 GodotStuff Dock 勾上。

如果想用到其它项目:整个复制 `addons/godotstuff_dock/` 目录过去,再在 Plugins 里启用。

## 跑起来

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```

**重要**:这个 demo 的核心**在编辑器里**,不是运行时。打开 Godot 编辑器后:
- 左下角(Inspector 旁的 dock)有 "📋 GodotStuff" 面板
- 切到 **Stats** 标签 → 显示当前打开场景的节点统计
- 切到 **Notes** 标签 → 写字自动保存到 `res://project_notes.md`
- 顶部 **Project → Tools → GodotStuff: Reset Notes** 清空笔记

## 学到什么

### 1. plugin.cfg 是什么
EditorPlugin 的入口清单:
```ini
[plugin]
name="GodotStuff Dock"
description="..."
author="godotstuff"
version="1.0"
script="plugin.gd"        # 相对 plugin.cfg 的脚本路径
```
没这个文件,Godot 不知道这是个插件。

### 2. EditorPlugin 生命周期
```gdscript
@tool                     # 关键!@tool 让代码在编辑器里运行
extends EditorPlugin

func _enter_tree():        # 插件启用时
    add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_BR, _dock)
    add_tool_menu_item("My Item", _callback)

func _exit_tree():         # 插件禁用时(或编辑器关闭)
    remove_control_from_docks(_dock)
    remove_tool_menu_item("My Item")
```
**没 `@tool`** → 你写的代码只在游戏运行时跑,**编辑器里不动**,插件等于死的。

### 3. EditorPlugin 能做什么(API 速查)

| API | 作用 |
|------|------|
| `add_control_to_dock(slot, control)` | 8 个 dock 槽,加自定义面板 |
| `add_control_to_bottom_panel(c, title)` | 加底部面板(像 Output / Debugger 那种) |
| `add_control_to_container(slot, c)` | 加到上方工具栏 |
| `add_tool_menu_item(name, callback)` | Project → Tools 菜单项 |
| `add_custom_type(name, parent, script, icon)` | 加自定义节点类型,Create Node 里能选 |
| `add_inspector_plugin(plugin)` | 自定义 Inspector 控件(展开 export var 的方式) |
| `add_import_plugin(plugin)` | 自定义资源导入器 |
| `add_export_plugin(plugin)` | 影响发布流程 |
| `add_scene_format_importer_plugin(...)` | 自定义场景格式(支持非 .tscn) |
| `add_node_3d_gizmo_plugin(...)` | 3D 视口的可视化辅助控件 |

### 4. EditorInterface = 编辑器全局 API
```gdscript
var ei := get_editor_interface()
ei.get_edited_scene_root()              # 当前打开场景的根节点
ei.get_selection().get_selected_nodes() # 选中的节点
ei.open_scene_from_path(path)
ei.save_scene()
ei.get_resource_filesystem()            # 文件系统 dock
```
本 demo 的 Stats 就是遍历 `get_edited_scene_root()` 的子树。

### 5. 信号 `scene_changed`
```gdscript
scene_changed.connect(_on_scene_changed)

func _on_scene_changed(new_root: Node):
    # 玩家切了别的场景标签
    refresh_stats()
```
EditorPlugin 自带的信号,在切场景时触发。还有 `resource_saved`、`script_changed` 等。

### 6. Dock 槽位常量
```
DOCK_SLOT_LEFT_UL    左上
DOCK_SLOT_LEFT_UR    
DOCK_SLOT_LEFT_BL    
DOCK_SLOT_LEFT_BR    左下(本 demo)
DOCK_SLOT_RIGHT_UL
DOCK_SLOT_RIGHT_UR
DOCK_SLOT_RIGHT_BL
DOCK_SLOT_RIGHT_BR
```
用户可以拖,但插件指定的是**初始位置**。

### 7. 自动保存(debounce)
```gdscript
notes_edit.text_changed.connect(func(): _save_timer.start())
# Timer wait_time=0.6, one_shot=true
# timer.timeout -> _save_notes()
```
**每次 text_changed 都 restart timer**:玩家停止打字 0.6 秒后才落盘,避免每键一写。

### 8. `res://` 在编辑器里是**可写**的
游戏运行时 `res://` 是只读(打到 .pck 里),但**在编辑器里**`FileAccess.open("res://foo", WRITE)` 能写进项目目录。
本 demo 的 notes 写在 `res://project_notes.md`,所以**会随项目 git 走** —— 团队成员共享笔记。

要"全局笔记"(不入 git)?换 `user://godotstuff_notes.md`。

## addons/ 目录的约定

```
addons/
├── plugin_name/
│   ├── plugin.cfg           ← 必须
│   ├── plugin.gd            ← @tool extends EditorPlugin,必须
│   ├── 其它 .gd / .tscn / 资源
│   └── icon.svg             ← (可选)Plugins 列表显示的图标
```
- 多个插件并存就是多个 `addons/<plugin>/` 子目录
- 在 `Project Settings → Plugins` 独立启用/禁用
- 跨项目复用 = 直接复制目录

## 改造练习

1. **Selected nodes operation**:在 Stats 上加个按钮"Select all of type X",遍历选中所有 Label 类型节点。
2. **快速 .tscn 解析**:Notes 里贴一段 tscn 文本,按钮 "Convert to graph",输出节点树。
3. **场景模板**:Tools 菜单 + Notes 模式,加 "Insert FPS template" → 在当前场景下生成 demo 21 的角色 + 相机骨架。
4. **快捷资源**:做个自定义节点 `add_custom_type("Hero", "CharacterBody2D", preload(...), icon)`,Create Node 列表里直接出现。
5. **保存为模板**:Project → Tools → "Export project as template",zip 当前 addons/ + 一些 base scene 到 user://templates/。

## 易踩坑

- **没 `@tool`**:`_enter_tree` 不会在编辑器里被调用,插件就是死的。一定要在脚本最顶端。
- 插件里 `print()` 输出到**编辑器底部的 Output 面板**,不是游戏运行时控制台。
- `add_control_to_dock` 注册的 Control **是引用**:用 `queue_free()` 销毁前**先 `remove_control_from_docks`**,顺序错了 Godot 会留 dangling reference。
- 修改了 plugin.gd 不会自动 reload:**Project → Reload Current Project** 或者 disable+enable 插件一遍。
- `@tool` 脚本的代码在编辑器里跑,**慎用副作用**(比如别在 `_ready` 里写文件,你打开项目就会被改)。
- 真要发布到 Godot Asset Library:目录名要在 `addons/` 下唯一,版本号要符合 `x.y` 格式,plugin.cfg 要有完整字段。
- 在不同 Godot 版本之间,EditorPlugin API **有破坏性变更**(3.x → 4.x 改名一堆)。
