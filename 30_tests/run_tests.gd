extends SceneTree

# Headless 测试运行器(CI 用):
#   godot --headless --path . --script res://run_tests.gd
# 退出码:全过 = 0,有失败 = 1(CI 据此判定 pass/fail)
#
# 自动发现所有 test_*.gd,运行,打印汇总。

const TEST_DIR := "res://"

func _init() -> void:
	var suites := _discover_test_scripts()
	var total_pass := 0
	var total_fail := 0
	var total_assert := 0
	var all_failures: Array = []

	print("\n========== RUNNING TESTS ==========\n")

	for path in suites:
		var script: GDScript = load(path)
		var instance = script.new()
		if not instance.has_method("run"):
			push_warning("跳过(不是 TestCase): " + path)
			continue
		var result: Dictionary = instance.run()
		total_pass += result.passed
		total_fail += result.failed
		total_assert += result.assertions
		all_failures.append_array(result.failures)

		var icon := "PASS" if result.failed == 0 else "FAIL"
		print("[%s] %-26s  %d passed, %d failed" % [
			icon, result.suite, result.passed, result.failed
		])

	print("\n========== SUMMARY ==========")
	print("suites:     %d" % suites.size())
	print("passed:     %d" % total_pass)
	print("failed:     %d" % total_fail)
	print("assertions: %d" % total_assert)

	if all_failures.size() > 0:
		print("\n--- FAILURES ---")
		for f in all_failures:
			print(f)

	print("")
	# 退出码给 CI
	quit(0 if total_fail == 0 else 1)

func _discover_test_scripts() -> Array:
	var out: Array = []
	var dir := DirAccess.open(TEST_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.begins_with("test_") and fname.ends_with(".gd"):
			out.append(TEST_DIR + fname)
		fname = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out
