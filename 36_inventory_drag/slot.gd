extends Panel
class_name InventorySlot

# ╔══════════════════════════════════════════════════════════════╗
# ║  一个背包格子。实现 Godot Control 的拖放三件套:               ║
# ║   _get_drag_data(pos)             拖出时:返回被拖的数据 + 预览  ║
# ║   _can_drop_data(pos, data)       悬停时:能不能放?(决定光标)  ║
# ║   _drop_data(pos, data)           松手时:放下,执行交换/堆叠    ║
# ╚══════════════════════════════════════════════════════════════╝

var item: String = ""        # 物品 id,空 = 空格
var qty: int = 0

@onready var icon: ColorRect = $Icon
@onready var count_label: Label = $Count

func _ready() -> void:
	refresh()

func set_item(p_item: String, p_qty: int) -> void:
	item = p_item
	qty = p_qty
	refresh()

func clear() -> void:
	item = ""
	qty = 0
	refresh()

func is_empty() -> bool:
	return item == "" or qty <= 0

func refresh() -> void:
	if is_empty():
		icon.color = Color(1, 1, 1, 0.04)
		count_label.text = ""
	else:
		icon.color = Inventory.item_color(item)
		count_label.text = str(qty) if qty > 1 else ""

# ── 拖放 API ─────────────────────────────────────────────────

func _get_drag_data(_pos: Vector2) -> Variant:
	if is_empty():
		return null
	# 拖动预览(跟随光标的小图)
	var preview := Panel.new()
	preview.custom_minimum_size = Vector2(56, 56)
	var p_icon := ColorRect.new()
	p_icon.color = Inventory.item_color(item)
	p_icon.size = Vector2(48, 48)
	p_icon.position = Vector2(4, 4)
	preview.add_child(p_icon)
	set_drag_preview(preview)

	# 返回的数据 = 拖动载荷(谁拖的、什么物品)
	var payload := { "from": self, "item": item, "qty": qty }
	return payload

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	# 只接受我们自己的背包载荷
	return data is Dictionary and data.has("item")

func _drop_data(_pos: Vector2, data: Variant) -> void:
	var from: InventorySlot = data["from"]
	if from == self:
		return

	if is_empty():
		# 放进空格
		set_item(data["item"], data["qty"])
		from.clear()
	elif item == data["item"]:
		# 同物品 → 堆叠
		qty += data["qty"]
		from.clear()
		refresh()
	else:
		# 不同物品 → 交换
		var tmp_item := item
		var tmp_qty := qty
		set_item(data["item"], data["qty"])
		from.set_item(tmp_item, tmp_qty)
