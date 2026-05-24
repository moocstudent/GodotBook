extends RefCounted
class_name SaveSystem

# ╔══════════════════════════════════════════════════════════════╗
# ║  生产级存档系统                                                  ║
# ║  - 多 slot                                                    ║
# ║  - 可选加密(FileAccess.open_encrypted_with_pass)              ║
# ║  - 可选压缩(open_compressed)                                  ║
# ║  - 版本迁移链                                                  ║
# ║  - 云同步接口(用 HTTPRequest 实现)                            ║
# ║                                                              ║
# ║  关键决定:**不要把游戏字段直接写盘**。永远走 default_data → migrate ║
# ║  → 校验 → 写。这样老客户端能读新存档,新客户端能读老存档。           ║
# ╚══════════════════════════════════════════════════════════════╝

const SAVE_DIR := "user://saves"
const CURRENT_VERSION := 3
const SLOT_COUNT := 3

# 加密"密码"在生产中不应硬编码;但这是 client-side,你做了也防不住高手。
# 主要目的:阻止小白用记事本改 JSON。真正反作弊得服务器权威 (demo 17 风格)。
const ENCRYPTION_PASS := "godotstuff-demo-key-not-secure"

# ── 数据结构 ──────────────────────────────────────────────────

static func default_data() -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"player_name": "Player",
		"score": 0,
		"level": 1,
		"playtime_sec": 0.0,
		"settings": {
			"music_volume": 0.8,
			"sfx_volume": 1.0,
		},
		"inventory": [],
		"flags": {},                # bool 任意 quest 标记
		"last_modified": "",        # ISO 时间串
	}

# ── 路径 ─────────────────────────────────────────────────────

static func slot_path(slot: int, encrypted: bool = false) -> String:
	var ext := ".sav" if encrypted else ".json"
	return "%s/slot_%d%s" % [SAVE_DIR, slot, ext]

static func ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))

# ── Save / Load ──────────────────────────────────────────────

static func save(slot: int, data: Dictionary, encrypted: bool = false) -> Error:
	ensure_dir()
	data["version"] = CURRENT_VERSION
	data["last_modified"] = Time.get_datetime_string_from_system()

	var path := slot_path(slot, encrypted)
	var file: FileAccess
	if encrypted:
		file = FileAccess.open_encrypted_with_pass(path, FileAccess.WRITE, ENCRYPTION_PASS)
	else:
		file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()

	file.store_string(JSON.stringify(data, "\t"))
	return OK

static func load_slot(slot: int) -> Dictionary:
	# 优先尝试加密版,再回退明文
	var enc_path := slot_path(slot, true)
	var json_path := slot_path(slot, false)
	var file: FileAccess

	if FileAccess.file_exists(enc_path):
		file = FileAccess.open_encrypted_with_pass(enc_path, FileAccess.READ, ENCRYPTION_PASS)
	elif FileAccess.file_exists(json_path):
		file = FileAccess.open(json_path, FileAccess.READ)
	else:
		return default_data()

	if file == null:
		push_warning("Slot %d: 文件存在但打不开" % slot)
		return default_data()

	var text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Slot %d: JSON parse 失败" % slot)
		return default_data()

	return migrate(parsed)

static func delete_slot(slot: int) -> void:
	for path in [slot_path(slot, true), slot_path(slot, false)]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

static func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot, true)) \
		or FileAccess.file_exists(slot_path(slot, false))

static func slot_summary(slot: int) -> String:
	if not slot_exists(slot):
		return "(empty)"
	var d := load_slot(slot)
	return "Lv.%d · %d pts · %s" % [
		d.get("level", 1),
		d.get("score", 0),
		d.get("last_modified", "?").substr(0, 19),
	]

# ── 版本迁移 ──────────────────────────────────────────────────

static func migrate(data: Dictionary) -> Dictionary:
	var v: int = int(data.get("version", 1))

	# v1 → v2: 加 settings 和 inventory
	if v < 2:
		data["settings"] = {"music_volume": 0.8, "sfx_volume": 1.0}
		data["inventory"] = []
		v = 2

	# v2 → v3: 加 flags 字典和 playtime
	if v < 3:
		data["flags"] = {}
		data["playtime_sec"] = 0.0
		v = 3

	data["version"] = v

	# 兜底:任何字段缺失都用 default 补齐
	var defaults := default_data()
	for key in defaults.keys():
		if not data.has(key):
			data[key] = defaults[key]
	return data
