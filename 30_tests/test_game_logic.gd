extends TestCase

# 示例测试套件。每个 test_* 方法是一个测试。
# 故意留一个失败的(test_intentional_failure)演示报错输出 —— 真用时删掉。

var inv: GameLogic.Inventory

func before_each() -> void:
	inv = GameLogic.Inventory.new()

# ── damage ────────────────────────────────────────────────────

func test_damage_basic() -> void:
	assert_eq(GameLogic.damage(50, 20), 30)

func test_damage_minimum_one() -> void:
	# 防御高于攻击,仍造成 1 点
	assert_eq(GameLogic.damage(10, 100), 1)

func test_damage_equal() -> void:
	assert_eq(GameLogic.damage(30, 30), 1)

# ── xp / level ────────────────────────────────────────────────

func test_xp_curve() -> void:
	assert_eq(GameLogic.xp_for_level(1), 100)
	assert_eq(GameLogic.xp_for_level(5), 2500)

func test_level_for_xp() -> void:
	assert_eq(GameLogic.level_for_xp(0), 1)
	assert_eq(GameLogic.level_for_xp(2500), 5)
	assert_eq(GameLogic.level_for_xp(2499), 4)

# ── stacking ──────────────────────────────────────────────────

func test_stack_fits() -> void:
	var r := GameLogic.stack(10, 5, 99)
	assert_eq(r[0], 15)
	assert_eq(r[1], 0)

func test_stack_overflow() -> void:
	var r := GameLogic.stack(95, 10, 99)
	assert_eq(r[0], 99, "should cap at max")
	assert_eq(r[1], 6, "6 overflow")

# ── inventory(用 before_each 重置)─────────────────────────────

func test_inventory_add() -> void:
	inv.add("potion", 3)
	inv.add("potion", 2)
	assert_eq(inv.count("potion"), 5)

func test_inventory_remove() -> void:
	inv.add("gold", 100)
	assert_true(inv.remove("gold", 30))
	assert_eq(inv.count("gold"), 70)

func test_inventory_remove_too_many() -> void:
	inv.add("key", 1)
	assert_false(inv.remove("key", 2), "can't remove more than have")
	assert_eq(inv.count("key"), 1, "unchanged on failed remove")

func test_inventory_isolation() -> void:
	# 证明 before_each 起作用:这个 inv 应该是空的
	assert_eq(inv.count("potion"), 0, "before_each should reset inventory")

# ── 故意失败(演示报错格式;真实使用请删除)───────────────────
func test_intentional_failure() -> void:
	assert_eq(1 + 1, 3, "this is a deliberate failure demo")
