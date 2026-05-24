extends Control

@onready var run_btn: Button = %RunBtn
@onready var summary: Label = %Summary
@onready var output: RichTextLabel = %Output

func _ready() -> void:
	run_btn.pressed.connect(_run)
	_run()

func _run() -> void:
	output.clear()
	var suites := _discover()
	var tp := 0
	var tf := 0
	var ta := 0
	var fails: Array = []

	for path in suites:
		var script: GDScript = load(path)
		var inst = script.new()
		if not inst.has_method("run"):
			continue
		var r: Dictionary = inst.run()
		tp += r.passed; tf += r.failed; ta += r.assertions
		fails.append_array(r.failures)
		var color := "#6cd070" if r.failed == 0 else "#ef656f"
		output.append_text("[color=%s]%s[/color]  %s — %d passed, %d failed\n" % [
			color, ("PASS" if r.failed == 0 else "FAIL"), r.suite, r.passed, r.failed
		])

	if fails.size() > 0:
		output.append_text("\n[color=#ef656f]--- failures ---[/color]\n")
		for f in fails:
			output.append_text("[color=#ef9999]%s[/color]\n" % f)

	var ok := tf == 0
	summary.text = "%d passed · %d failed · %d assertions" % [tp, tf, ta]
	summary.modulate = Color(0.4, 0.85, 0.45) if ok else Color(0.95, 0.4, 0.4)

func _discover() -> Array:
	var out: Array = []
	var dir := DirAccess.open("res://")
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.begins_with("test_") and f.ends_with(".gd"):
			out.append("res://" + f)
		f = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
