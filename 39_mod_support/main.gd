extends Control

@onready var mod_status: Label = %ModStatus
@onready var items_list: VBoxContainer = %ItemsList
@onready var how_to: RichTextLabel = %HowTo

func _ready() -> void:
	# 1) 先挂载所有 mod(必须在读取数据之前)
	var mods := ModLoader.load_all()

	# 2) 读合并后的数据
	var items := ModLoader.load_items()

	# 3) 显示
	if mods.is_empty():
		mod_status.text = "未发现 mod。把 .pck / .zip 放到:\n%s" % ProjectSettings.globalize_path("user://mods")
	else:
		var lines := []
		for m in mods:
			lines.append("%s [%s]" % [m.file, "OK" if m.ok else "FAILED"])
		mod_status.text = "已加载 %d 个 mod:%s" % [mods.size(), ", ".join(lines)]

	for id in items:
		var it: Dictionary = items[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(28, 28)
		swatch.color = Color.from_string(it.get("color", "#888888"), Color.GRAY)
		row.add_child(swatch)

		var lbl := Label.new()
		lbl.text = "%s  (%s)  damage=%d" % [it.get("name", id), id, int(it.get("damage", 0))]
		row.add_child(lbl)

		items_list.add_child(row)

	_show_howto()

func _show_howto() -> void:
	how_to.text = "[b]怎么做一个 mod:[/b]
1. 在 Godot 里新建一个临时项目,放 [code]base_items.json[/code](或新建 [code]mods_data/my_mod.json[/code])改物品数据
2. Project → Export → 加一个 [code]Pack/Zip[/code] 预设(或任意平台预设)
3. 用 [b]Export PCK/Zip[/b] 导出成 [code]my_mod.pck[/code]
4. 放到 [code]user://mods/[/code] 目录(本机:见上方路径)
5. 重启本 demo → mod 数据自动合并进物品列表

[b]数据约定:[/b]同名 id 覆盖(改平衡),新 id 新增(加内容)。
[b]安全警告:[/b].pck 里可以包含 [code].gd[/code] 脚本,加载后会执行 —— 等于让玩家运行任意代码。商业游戏要么只允许数据 mod(json/png),要么沙箱化。"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
