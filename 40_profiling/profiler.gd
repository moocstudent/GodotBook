extends CanvasLayer
class_name Profiler

# ╔══════════════════════════════════════════════════════════════╗
# ║  自定义性能叠加层                                              ║
# ║   - FPS / 帧时间(ms)+ 帧预算条(16.6ms=60fps 红线)           ║
# ║   - 自定义计时段:Profiler.begin("ai") ... Profiler.end("ai")  ║
# ║   - 对象 / 节点数                                             ║
# ╚══════════════════════════════════════════════════════════════╝

var _label: Label
var _graph: ColorRect
var _frame_times: Array[float] = []
var _sections := {}              # name -> 本帧累计 usec
var _section_start := {}
var custom_text := ""

func _ready() -> void:
	layer = 100
	_label = Label.new()
	_label.position = Vector2(12, 12)
	_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	_label.add_theme_font_size_override("font_size", 15)
	add_child(_label)

func begin(section: String) -> void:
	_section_start[section] = Time.get_ticks_usec()

func end(section: String) -> void:
	if _section_start.has(section):
		var dt := Time.get_ticks_usec() - _section_start[section]
		_sections[section] = dt

func _process(delta: float) -> void:
	var ft := delta * 1000.0
	_frame_times.append(ft)
	if _frame_times.size() > 60:
		_frame_times.pop_front()

	var avg := 0.0
	var mx := 0.0
	for t in _frame_times:
		avg += t
		mx = max(mx, t)
	avg /= max(1, _frame_times.size())

	var budget_pct := (avg / 16.6667) * 100.0
	var lines := []
	lines.append("FPS: %d   frame: %.2f ms (max %.2f)" % [Engine.get_frames_per_second(), avg, mx])
	lines.append("frame budget (60fps=16.6ms): %.0f%%" % budget_pct)
	lines.append("nodes: %d   objects: %d" % [
		get_tree().get_node_count(),
		Performance.get_monitor(Performance.OBJECT_COUNT),
	])
	lines.append("draw calls: %d   video mem: %.1f MB" % [
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
	])
	for s in _sections:
		lines.append("  [%s] %.3f ms" % [s, _sections[s] / 1000.0])
	if custom_text != "":
		lines.append(custom_text)

	_label.text = "\n".join(lines)
