extends RefCounted
class_name TestCase

# ╔══════════════════════════════════════════════════════════════╗
# ║  极简测试框架(~80 行)。继承它写测试类:                       ║
# ║                                                              ║
# ║    extends TestCase                                          ║
# ║    func test_addition():                                    ║
# ║        assert_eq(2 + 2, 4)                                   ║
# ║                                                              ║
# ║  约定:所有 test_* 开头的方法被自动发现并运行。                  ║
# ║  before_each() / after_each() 在每个 test 前后跑。            ║
# ║                                                              ║
# ║  生产环境用 GUT(见 README),概念一致。                        ║
# ╚══════════════════════════════════════════════════════════════╝

var _failures: Array[String] = []
var _current_test := ""
var _assertions := 0

# 子类可覆盖
func before_each() -> void: pass
func after_each() -> void: pass

# ── 断言 ──────────────────────────────────────────────────────

func assert_true(cond: bool, msg := "") -> void:
	_assertions += 1
	if not cond:
		_fail("assert_true failed. " + msg)

func assert_false(cond: bool, msg := "") -> void:
	_assertions += 1
	if cond:
		_fail("assert_false failed. " + msg)

func assert_eq(a, b, msg := "") -> void:
	_assertions += 1
	if a != b:
		_fail("assert_eq failed: %s != %s. %s" % [a, b, msg])

func assert_ne(a, b, msg := "") -> void:
	_assertions += 1
	if a == b:
		_fail("assert_ne failed: %s == %s. %s" % [a, b, msg])

func assert_almost_eq(a: float, b: float, tol := 0.0001, msg := "") -> void:
	_assertions += 1
	if absf(a - b) > tol:
		_fail("assert_almost_eq failed: %f vs %f (tol %f). %s" % [a, b, tol, msg])

func assert_null(v, msg := "") -> void:
	_assertions += 1
	if v != null:
		_fail("assert_null failed: got %s. %s" % [v, msg])

func assert_not_null(v, msg := "") -> void:
	_assertions += 1
	if v == null:
		_fail("assert_not_null failed. " + msg)

func _fail(reason: String) -> void:
	_failures.append("  [%s] %s" % [_current_test, reason])

# ── 运行器:发现并跑所有 test_* 方法 ──────────────────────────

# 返回 {passed, failed, assertions, failures}
func run() -> Dictionary:
	_failures.clear()
	_assertions = 0
	var passed := 0
	var failed := 0

	for m in get_method_list():
		var mname: String = m["name"]
		if not mname.begins_with("test_"):
			continue
		_current_test = mname
		var before := _failures.size()
		before_each()
		callv(mname, [])
		after_each()
		if _failures.size() == before:
			passed += 1
		else:
			failed += 1

	return {
		"suite": get_script().resource_path.get_file(),
		"passed": passed,
		"failed": failed,
		"assertions": _assertions,
		"failures": _failures.duplicate(),
	}
