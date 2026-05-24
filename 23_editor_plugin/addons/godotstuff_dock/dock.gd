@tool
extends VBoxContainer

const NOTES_PATH := "res://project_notes.md"

@onready var stats: RichTextLabel = %StatsLabel
@onready var notes_edit: TextEdit = %NotesEdit
@onready var refresh_btn: Button = $Tabs/Stats/RefreshBtn

var _editor: EditorInterface
var _save_timer: Timer

func _ready() -> void:
	refresh_btn.pressed.connect(refresh_stats)

	# notes 自动保存:debounce 0.6 秒
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.6
	_save_timer.timeout.connect(_save_notes)
	add_child(_save_timer)

	notes_edit.text_changed.connect(func(): _save_timer.start())
	_load_notes()
	refresh_stats()

func set_editor_interface(ei: EditorInterface) -> void:
	_editor = ei
	refresh_stats()

func set_scene_root(_root: Node) -> void:
	refresh_stats()

# ── Scene Stats ───────────────────────────────────────────────

func refresh_stats() -> void:
	if _editor == null:
		stats.text = "(editor not ready)"
		return
	var root := _editor.get_edited_scene_root()
	if root == null:
		stats.text = "(no scene open)"
		return

	var counts := {}
	var total := _walk(root, counts)
	var lines: Array[String] = []
	lines.append("[b]scene:[/b] %s" % root.name)
	lines.append("[b]total nodes:[/b] %d" % total)
	lines.append("")
	lines.append("[b]by type:[/b]")

	var keys := counts.keys()
	keys.sort_custom(func(a, b): return counts[b] < counts[a])  # 多的在前
	for k in keys:
		lines.append("  [color=#aaaaaa]%-22s[/color] %d" % [k, counts[k]])

	stats.text = "\n".join(lines)

func _walk(n: Node, counts: Dictionary) -> int:
	var cls := n.get_class()
	counts[cls] = counts.get(cls, 0) + 1
	var total := 1
	for c in n.get_children():
		total += _walk(c, counts)
	return total

# ── Notes 持久化 ──────────────────────────────────────────────

func _load_notes() -> void:
	if FileAccess.file_exists(NOTES_PATH):
		var f := FileAccess.open(NOTES_PATH, FileAccess.READ)
		notes_edit.text = f.get_as_text()

func _save_notes() -> void:
	var f := FileAccess.open(NOTES_PATH, FileAccess.WRITE)
	if f:
		f.store_string(notes_edit.text)

func reset_notes() -> void:
	notes_edit.text = ""
	_save_notes()
