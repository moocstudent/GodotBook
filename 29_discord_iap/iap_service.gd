extends Node
class_name IAPService

# ╔══════════════════════════════════════════════════════════════╗
# ║  内购(In-App Purchase)抽象层                                  ║
# ║                                                              ║
# ║  现实:Android 用 Google Play Billing,iOS 用 StoreKit,       ║
# ║  各自有 Godot 插件(GodotGooglePlayBilling / 第三方 StoreKit)。 ║
# ║  这一层把它们藏在统一接口后面,游戏逻辑只调:                    ║
# ║    iap.query_products([...])                                 ║
# ║    iap.purchase("remove_ads")                                ║
# ║    iap.restore_purchases()                                   ║
# ║                                                              ║
# ║  没插件时(桌面 / 开发期)用一个 fake 后端模拟,流程一模一样。   ║
# ╚══════════════════════════════════════════════════════════════╝

signal products_loaded(products: Array)
signal purchase_succeeded(product_id: String)
signal purchase_failed(product_id: String, reason: String)
signal purchase_restored(product_id: String)

enum Platform { NONE, GOOGLE_PLAY, APP_STORE, FAKE }

var platform := Platform.FAKE
var _owned: Dictionary = {}            # product_id -> true(已购,持久化应存盘)
var _catalog := {
	"remove_ads":   {"title": "去广告",      "price": "¥6",  "type": "non_consumable"},
	"coins_100":    {"title": "100 金币",    "price": "¥6",  "type": "consumable"},
	"coins_500":    {"title": "500 金币",    "price": "¥25", "type": "consumable"},
	"premium":      {"title": "高级版",      "price": "¥30", "type": "non_consumable"},
}

func _ready() -> void:
	# 检测真实计费插件;没有就 FAKE
	if Engine.has_singleton("GodotGooglePlayBilling"):
		platform = Platform.GOOGLE_PLAY
		_init_google_play()
	elif Engine.has_singleton("InAppStore"):     # iOS StoreKit 插件名(示意)
		platform = Platform.APP_STORE
		_init_app_store()
	else:
		platform = Platform.FAKE
		push_warning("无计费插件 → IAP 走 fake 模拟(开发模式)")

func platform_name() -> String:
	match platform:
		Platform.GOOGLE_PLAY: return "Google Play Billing"
		Platform.APP_STORE: return "Apple StoreKit"
		Platform.FAKE: return "FAKE (dev)"
		_: return "none"

# ── 统一接口 ──────────────────────────────────────────────────

func query_products(ids: Array = []) -> void:
	var list := []
	for id in (_catalog.keys() if ids.is_empty() else ids):
		var p: Dictionary = _catalog.get(id, {}).duplicate()
		p["id"] = id
		p["owned"] = _owned.has(id)
		list.append(p)
	# 真实平台是异步的;这里直接发(fake)
	products_loaded.emit(list)

func purchase(product_id: String) -> void:
	match platform:
		Platform.GOOGLE_PLAY:
			Engine.get_singleton("GodotGooglePlayBilling").purchase(product_id)
			# 结果通过 connect 的信号回调
		Platform.APP_STORE:
			Engine.get_singleton("InAppStore").purchase({"product_id": product_id})
		Platform.FAKE:
			_fake_purchase(product_id)

func restore_purchases() -> void:
	match platform:
		Platform.GOOGLE_PLAY:
			Engine.get_singleton("GodotGooglePlayBilling").queryPurchases("inapp")
		Platform.APP_STORE:
			Engine.get_singleton("InAppStore").restorePurchases()
		Platform.FAKE:
			for id in _owned:
				purchase_restored.emit(id)

func is_owned(product_id: String) -> bool:
	return _owned.has(product_id)

# ── FAKE 实现(模拟异步 + 80% 成功率)──────────────────────────

func _fake_purchase(product_id: String) -> void:
	await get_tree().create_timer(0.8).timeout    # 模拟支付弹窗延迟
	if randf() < 0.85:
		var ptype: String = _catalog.get(product_id, {}).get("type", "consumable")
		if ptype == "non_consumable":
			_owned[product_id] = true
		purchase_succeeded.emit(product_id)
	else:
		purchase_failed.emit(product_id, "用户取消 / 网络错误(模拟)")

# ── 真实平台初始化(示意,需对应插件)──────────────────────────

func _init_google_play() -> void:
	var billing = Engine.get_singleton("GodotGooglePlayBilling")
	billing.connected.connect(func(): billing.querySkuDetails(_catalog.keys(), "inapp"))
	billing.purchases_updated.connect(_on_gp_purchases)
	billing.sku_details_query_completed.connect(_on_gp_skus)
	billing.startConnection()

func _on_gp_purchases(purchases: Array) -> void:
	for p in purchases:
		# 必须 acknowledge / consume,否则 3 天后自动退款!
		_owned[p.sku] = true
		purchase_succeeded.emit(p.sku)

func _on_gp_skus(_skus: Array) -> void:
	pass    # 用真实价格/标题覆盖 _catalog

func _init_app_store() -> void:
	pass    # StoreKit 插件初始化
