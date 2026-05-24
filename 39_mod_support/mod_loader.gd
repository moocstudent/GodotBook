extends RefCounted
class_name ModLoader

# ╔══════════════════════════════════════════════════════════════╗
# ║  Mod 加载器                                                    ║
# ║                                                              ║
# ║  Godot 支持运行时挂载额外资源包:                              ║
# ║    ProjectSettings.load_resource_pack("user://mods/x.pck")   ║
# ║  挂载后,pck 里的文件**覆盖或新增**到 res:// 虚拟文件系统。     ║
# ║  .zip 也支持(同 API)。                                       ║
# ║                                                              ║
# ║  典型 mod 目录:                                              ║
# ║    user://mods/                                              ║
# ║      cool_weapons/                                           ║
# ║        mod.json          ← 清单(名字/版本/作者)            ║
# ║        items.json        ← 覆盖/新增数据                      ║
# ║        (打包成 cool_weapons.pck 或 .zip)                     ║
# ╚══════════════════════════════════════════════════════════════╝

const MODS_DIR := "user://mods"

# 加载所有 mod 的 *.pck / *.zip,返回已加载 mod 清单数组
static func load_all() -> Array:
	var loaded: Array = []
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MODS_DIR))

	var dir := DirAccess.open(MODS_DIR)
	if dir == null:
		return loaded

	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".pck") or fname.ends_with(".zip"):
			var path := MODS_DIR + "/" + fname
			# replace_files = true:mod 文件覆盖同名 res:// 文件
			var ok := ProjectSettings.load_resource_pack(path, true)
			loaded.append({ "file": fname, "ok": ok })
		fname = dir.get_next()
	dir.list_dir_end()
	return loaded

# 合并基础数据 + mod 数据(mod 覆盖同 key,新增不同 key)
# 约定:基础在 res://base_items.json,mod 把自己的 items.json 也放 res://(覆盖)
# 或放 res://mods_data/<name>.json(新增)。本 demo 用覆盖演示。
static func load_items() -> Dictionary:
	var result := {}
	# 1) 基础
	_merge_json_into(result, "res://base_items.json")
	# 2) mod 覆盖文件(若某 mod 包含 res://base_items.json,挂载后这里读到的就是 mod 版)
	#    多 mod 叠加数据建议各自放独立路径,这里演示扫描 mods_data/
	var dir := DirAccess.open("res://mods_data")
	if dir:
		dir.list_dir_begin()
		var f := dir.get_next()
		while f != "":
			if f.ends_with(".json"):
				_merge_json_into(result, "res://mods_data/" + f)
			f = dir.get_next()
		dir.list_dir_end()
	return result

static func _merge_json_into(target: Dictionary, path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	var d: Variant = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return
	var items: Dictionary = d.get("items", {})
	for k in items:
		target[k] = items[k]      # mod 同名覆盖,新名新增
