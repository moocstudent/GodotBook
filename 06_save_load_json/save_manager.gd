extends RefCounted
class_name SaveManager

# 存档路径用 user:// —— 跨平台,自动落到:
#   Windows : %APPDATA%\Godot\app_userdata\<项目名>\save.json
#   macOS   : ~/Library/Application Support/Godot/app_userdata/<项目名>/save.json
#   Linux   : ~/.local/share/godot/app_userdata/<项目名>/save.json
#   Android : 内部存储 app 沙盒
const SAVE_PATH := "user://save.json"

# 存档版本号 —— 改数据结构时升上来,migrate() 负责老存档兼容
const CURRENT_VERSION := 2

static func default_data() -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"player_name": "Player",
		"score": 0,
		"level": 1,
		"settings": {
			"music_volume": 0.8,
			"sfx_volume": 1.0,
		},
		"inventory": [],
	}

static func save(data: Dictionary) -> Error:
	data["version"] = CURRENT_VERSION
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	# JSON.stringify 第二个参数是缩进 -> 人类可读,方便调试
	file.store_string(JSON.stringify(data, "\t"))
	# Godot 4 里 FileAccess 走出作用域自动 close,显式 close 也可
	return OK

static func load_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return default_data()

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("存档文件存在但打不开,使用默认数据")
		return default_data()

	var text := file.get_as_text()
	# JSON.parse_string 失败返回 null;成功返回 Variant(通常是 Dictionary/Array)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("存档 JSON 损坏,使用默认数据")
		return default_data()

	return migrate(parsed)

static func delete() -> Error:
	if FileAccess.file_exists(SAVE_PATH):
		return DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	return OK

# 老存档迁移到新结构:每升级一次写一段
static func migrate(data: Dictionary) -> Dictionary:
	var v: int = data.get("version", 1)

	# v1 -> v2:新增 settings 子结构和 inventory 数组
	if v < 2:
		data["settings"] = {"music_volume": 0.8, "sfx_volume": 1.0}
		data["inventory"] = []
		v = 2

	data["version"] = v
	# 兜底:确保所有必需键都存在(防御用户手工编辑)
	var defaults := default_data()
	for key in defaults.keys():
		if not data.has(key):
			data[key] = defaults[key]
	return data

static func save_file_path() -> String:
	# 返回绝对路径,方便在 UI 上展示给用户"我的存档在哪"
	return ProjectSettings.globalize_path(SAVE_PATH)
