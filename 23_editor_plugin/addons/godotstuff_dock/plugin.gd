@tool
extends EditorPlugin

# @tool 让脚本在编辑器里就跑(而不仅游戏运行时)。
# EditorPlugin 的所有生命周期都发生在编辑器里。
const DockScene := preload("res://addons/godotstuff_dock/dock.tscn")
const MENU_LABEL := "GodotStuff: Reset Notes"

var _dock: Control

# 编辑器载入插件 / 项目打开 / 重新启用插件时触发
func _enter_tree() -> void:
	_dock = DockScene.instantiate()
	# 把 dock 实例化的 Control 加进编辑器左下角 dock 槽
	# 可用槽:DOCK_SLOT_LEFT_UL/UR/BL/BR, DOCK_SLOT_RIGHT_UL/...(共 8 个)
	add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_BR, _dock)
	_dock.set_editor_interface(get_editor_interface())

	# 顶部 Project → Tools 菜单加一项
	add_tool_menu_item(MENU_LABEL, _on_reset_notes)

	# 监听场景变化 -> 刷新 Stats
	scene_changed.connect(_on_scene_changed)

# 插件卸载 / 项目关闭 / 禁用时
func _exit_tree() -> void:
	remove_control_from_docks(_dock)
	remove_tool_menu_item(MENU_LABEL)
	if _dock:
		_dock.queue_free()
	if scene_changed.is_connected(_on_scene_changed):
		scene_changed.disconnect(_on_scene_changed)

func _on_reset_notes() -> void:
	if _dock and _dock.has_method("reset_notes"):
		_dock.reset_notes()

func _on_scene_changed(scene_root: Node) -> void:
	if _dock and _dock.has_method("set_scene_root"):
		_dock.set_scene_root(scene_root)
