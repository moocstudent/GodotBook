extends RefCounted
class_name Inventory

# 物品定义表(颜色 + 显示名)。真实游戏从资源 / JSON 加载。
const ITEMS := {
	"sword":  { "name": "寒铁剑",   "color": Color(0.7, 0.75, 0.85) },
	"potion": { "name": "治疗药水", "color": Color(0.9, 0.3, 0.4) },
	"gold":   { "name": "金币",     "color": Color(0.95, 0.8, 0.2) },
	"gem":    { "name": "宝石",     "color": Color(0.5, 0.85, 0.95) },
	"herb":   { "name": "草药",     "color": Color(0.4, 0.8, 0.45) },
	"key":    { "name": "钥匙",     "color": Color(0.85, 0.7, 0.3) },
}

static func item_color(id: String) -> Color:
	return ITEMS.get(id, {}).get("color", Color.GRAY)

static func item_name(id: String) -> String:
	return ITEMS.get(id, {}).get("name", id)
