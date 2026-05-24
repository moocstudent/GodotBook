# Demo 29 — Discord Rich Presence + IAP

两个常见"第三方集成"的**抽象层 + 优雅降级**:
1. **Discord Rich Presence** — 好友能在 Discord 看到你"正在玩什么"
2. **IAP(应用内购买)** — 移动端 Google Play / App Store 内购

没插件时全部用 fake 实现模拟,流程与真实一致。

## 跑起来

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```

- 顶部显示当前后端(无插件 → "FAKE (dev)" + "no-op")
- Discord 按钮:切换富存在状态(打印到 Log)
- 商店:点购买 → 模拟支付弹窗(0.8s)→ 85% 成功 → 非消耗品标记"已拥有"
- 恢复购买:把已拥有的重新发一遍(App Store 必需功能)

## 第一部分:Discord Rich Presence

### 是什么
好友列表里你的名字下显示:
```
正在玩 My Game
第 3 关 - Boss 战
组队中 (2/4)         [游戏图标]
已游玩 00:42
```

### 怎么接
1. **Discord Developer Portal** 建一个 Application,拿 `client_id`
2. 上传 art assets(大图标、小图标),记下 asset key
3. 装插件:**discord-rpc-gdextension** 或 **godotcord**(GDExtension,放 `addons/`)
4. 代码:
```gdscript
var rpc = Engine.get_singleton("DiscordRPC")
rpc.app_id = client_id
rpc.initialize()

# 设置状态
rpc.details = "第 3 关 - Boss 战"     # 第一行
rpc.state = "组队中"                  # 第二行
rpc.large_image = "game_logo"         # asset key
rpc.party_size = 2
rpc.party_max = 4
rpc.start_timestamp = unix_now        # 显示"已游玩 X 分钟"
rpc.refresh()

# 每帧 pump
func _process(_d): rpc.run_callbacks()
```

### 抽象层的价值
本 demo 的 `DiscordPresence` 包了一层:
```gdscript
discord.set_presence("第 3 关 - Boss 战", "血量 80%", 2, 4)
```
游戏逻辑只调这一行,不关心插件在不在、Discord 开没开。**桌面没 Discord、移动端根本没这功能** —— 抽象层让同一份游戏代码到处跑。

### Discord 还能做(进阶)
- **Join / Spectate**:好友点"加入游戏"直接进你的房间(配合 demo 17 联机)
- **Invite**:发邀请链接到频道
这些需要 OAuth + 你的联机后端配合,复杂度高。

## 第二部分:IAP(内购)

### 平台差异
| | Android | iOS |
|---|---------|-----|
| 系统 | Google Play Billing | StoreKit |
| Godot 插件 | GodotGooglePlayBilling(官方) | 第三方 StoreKit 插件 |
| 抽成 | 15-30% | 15-30% |
| 后台 | Play Console 配商品 | App Store Connect 配商品 |

### 商品类型
- **consumable(消耗品)**:金币、体力 —— 可重复买,买了即用掉
- **non-consumable(非消耗品)**:去广告、解锁高级版 —— 买一次永久拥有,要支持"恢复购买"
- **subscription(订阅)**:月卡 —— 定期续费

### 统一接口(本 demo 的 IAPService)
```gdscript
iap.query_products(["remove_ads", "coins_100"])   # 拉商品(价格/标题)
iap.purchase("remove_ads")                         # 发起购买
iap.restore_purchases()                            # 恢复(非消耗品)
iap.is_owned("remove_ads")                         # 查是否已购
```
信号:
```gdscript
iap.products_loaded
iap.purchase_succeeded
iap.purchase_failed
iap.purchase_restored
```

### Google Play 的关键坑:必须 acknowledge
```gdscript
billing.purchases_updated.connect(func(purchases):
    for p in purchases:
        # 消耗品 → consumePurchase(让它能再买)
        # 非消耗品 → acknowledgePurchase
        # **3 天内不 ack/consume,Google 自动退款!**
        billing.acknowledgePurchase(p.purchase_token)
)
```
**这是新手第一大坑**:玩家付了钱,你没 acknowledge,3 天后被自动退款,你白送了道具。

### 恢复购买(App Store 强制)
苹果审核要求:非消耗品 / 订阅必须有"恢复购买"按钮(玩家换设备 / 重装后找回)。没有会被拒。
```gdscript
func restore():
    StoreKit.restorePurchases()
    # 回调里把每个已购重新标记 owned
```

### 服务器验证(防破解)
客户端的购买回执可以伪造。**重要内购应该**:
1. 客户端拿到 receipt
2. 发给你的服务器
3. 服务器调 Google/Apple 的验证 API
4. 服务器确认后才发道具
本 demo 没做(纯客户端),真实付费游戏必做。

## 优雅降级(两个服务的共同模式)
```gdscript
var _has_plugin := Engine.has_singleton("GodotGooglePlayBilling")

func purchase(id):
    if not _has_plugin:
        _fake_purchase(id)    # 桌面/开发:模拟
        return
    # 真实平台调用
```
**为什么**:
- Godot 编辑器里(桌面)没有 Play Billing,但你要测商店 UI
- 同一份代码导出到 Android(真计费)和桌面(无计费)
- fake 实现让你在没设备时跑通整个购买流程逻辑

## 改造练习

1. **持久化已购**:把 `_owned` 存进 demo 22 的存档系统,重启后保留(非消耗品)。
2. **去广告生效**:`if iap.is_owned("remove_ads")` 时隐藏广告位。
3. **金币入账**:消耗品 `coins_100` 购买成功 → 玩家金币 +100 + 立即 consume。
4. **真接 GodotGooglePlayBilling**:Android 导出,Play Console 配测试商品,真机测试轨道测试。
5. **Discord Join**:配合 demo 17,好友点"加入"携带房间 IP 进游戏。
6. **订阅状态轮询**:月卡到期检测,过期降级。
7. **服务器验证**:配合 demo 16 的 HTTPRequest,把 receipt 发后端验证。

## 易踩坑

- **Google Play 不 acknowledge → 3 天自动退款**。最重要的一条。
- **App Store 没"恢复购买"按钮 → 审核被拒**。
- 内购插件**只在对应平台导出后**可用,编辑器里恒为 fake。别指望桌面测真支付。
- 购买回执**客户端可伪造**,付费游戏要服务器验证。
- 消耗品买了不 `consume` → 玩家无法二次购买(系统认为还没"用掉")。
- Discord RPC 要 Discord 客户端**正在运行**才显示;没开 Discord 静默失败。
- `Engine.has_singleton(...)` 检测插件,**不要在脚本顶层直接 `GodotGooglePlayBilling.xxx`**,没插件时整个脚本编译失败。本 demo 全程用 `Engine.get_singleton()` 动态访问。
- 商品 ID 在 Play Console / App Store Connect 后台**先注册**,代码里的 id 必须完全一致。
- 价格不要硬编码("¥6")—— 用平台返回的本地化价格(不同国家货币/价格不同)。本 demo 的 `_catalog` 价格仅占位。
