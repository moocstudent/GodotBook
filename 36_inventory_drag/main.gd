extends Control

const SlotScene := preload("res://slot.tscn")
const ROWS := 4
const COLS := 6

@onready var grid: GridContainer = %Grid
@onready var tooltip: Label = %Tooltip

var slots: Array[InventorySlot] = []

func _ready() -> void:
	grid.columns = COLS
	for i in ROWS * COLS:
		var slot: InventorySlot = SlotScene.instantiate()
		grid.add_child(slot)
		slot.mouse_entered.connect(_on_hover.bind(slot))
		slot.mouse_exited.connect(func(): tooltip.text = "")
		slots.append(slot)

	# 填一些初始物品
	slots[0].set_item("sword", 1)
	slots[1].set_item("potion", 5)
	slots[2].set_item("potion", 3)
	slots[3].set_item("gold", 240)
	slots[6].set_item("gem", 2)
	slots[7].set_item("herb", 12)
	slots[8].set_item("key", 1)

func _on_hover(slot: InventorySlot) -> void:
	if slot.is_empty():
		tooltip.text = ""
	else:
		tooltip.text = "%s ×%d  (%s)" % [
			Inventory.item_name(slot.item), slot.qty, slot.item
		]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
