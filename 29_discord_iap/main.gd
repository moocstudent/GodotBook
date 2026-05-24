extends Control

@onready var iap: IAPService = %IAP
@onready var discord: DiscordPresence = %Discord
@onready var backend_label: Label = %BackendLabel
@onready var shop_list: VBoxContainer = %ShopList
@onready var restore_btn: Button = %RestoreBtn
@onready var log_view: TextEdit = %Log

func _ready() -> void:
	await get_tree().process_frame
	backend_label.text = "IAP: %s   ·   Discord: %s" % [iap.platform_name(), discord.backend_name()]

	# Discord 按钮
	$Margin/VBox/DiscordRow/MenuBtn.pressed.connect(func():
		discord.set_presence("主菜单", "挂机中")
		_log("discord: 主菜单"))
	$Margin/VBox/DiscordRow/PlayBtn.pressed.connect(func():
		discord.set_presence("第 3 关 - Boss 战", "血量 80%")
		_log("discord: 第 3 关"))
	$Margin/VBox/DiscordRow/PartyBtn.pressed.connect(func():
		discord.set_presence("竞技场", "组队中", 2, 4)
		_log("discord: 组队 2/4"))

	# IAP 信号
	iap.products_loaded.connect(_on_products)
	iap.purchase_succeeded.connect(func(id):
		_log("✓ 购买成功: " + id)
		iap.query_products())   # 刷新 owned 状态
	iap.purchase_failed.connect(func(id, reason): _log("✗ 购买失败 %s: %s" % [id, reason]))
	iap.purchase_restored.connect(func(id): _log("↺ 已恢复: " + id))

	restore_btn.pressed.connect(func():
		iap.restore_purchases()
		_log("restore_purchases() called"))

	iap.query_products()

func _on_products(products: Array) -> void:
	for c in shop_list.get_children():
		c.queue_free()
	for p in products:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var label := Label.new()
		label.text = "%s  (%s)" % [p.title, p.price]
		label.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(label)

		var btn := Button.new()
		if p.owned:
			btn.text = "已拥有"
			btn.disabled = true
		else:
			btn.text = "购买"
			btn.pressed.connect(func():
				_log("buying %s ..." % p.id)
				iap.purchase(p.id))
		btn.custom_minimum_size = Vector2(100, 0)
		row.add_child(btn)

		shop_list.add_child(row)

func _log(line: String) -> void:
	log_view.text += line + "\n"
	log_view.scroll_vertical = 9999

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
