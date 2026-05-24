extends RefCounted
class_name GameLogic

# 被测代码示例:一些纯逻辑(最适合单元测试的部分)。
# 真实游戏里把"伤害计算/经验曲线/物品堆叠/存档迁移"这类纯函数抽出来,好测。

static func damage(attack: int, defense: int) -> int:
	# 至少造成 1 点伤害
	return maxi(1, attack - defense)

static func xp_for_level(level: int) -> int:
	# 平方曲线
	return level * level * 100

static func level_for_xp(xp: int) -> int:
	var lvl := 1
	while xp_for_level(lvl + 1) <= xp:
		lvl += 1
	return lvl

# 物品堆叠:返回 [放入数量, 溢出数量]
static func stack(current: int, adding: int, max_stack: int) -> Array:
	var space := max_stack - current
	var put := mini(space, adding)
	return [current + put, adding - put]

class Inventory extends RefCounted:
	var items: Dictionary = {}
	func add(item: String, qty: int) -> void:
		items[item] = items.get(item, 0) + qty
	func remove(item: String, qty: int) -> bool:
		if items.get(item, 0) < qty:
			return false
		items[item] -= qty
		if items[item] == 0:
			items.erase(item)
		return true
	func count(item: String) -> int:
		return items.get(item, 0)
