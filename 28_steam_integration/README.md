# Demo 28 — Steam 集成 (GodotSteam)

封装 Steamworks 常用功能(成就 / 排行榜 / 云存档 / 创意工坊)的 **wrapper + 优雅降级**。没装 GodotSteam 时全部 no-op,游戏照常跑(开发期、itch.io 版、demo 版都需要这个能力)。

## 跑起来

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```

没装 GodotSteam → 顶部显示 "未安装 → no-op",点按钮在 Log 里打印"本来会调用什么"。这就是 wrapper 的价值:**逻辑层不依赖 Steam 是否存在**。

## 学到什么

### 1. GodotSteam 是什么
[GodotSteam](https://github.com/GodotSteam/GodotSteam) = 把 Valve 的 **Steamworks SDK**(C++)暴露给 GDScript 的第三方 GDExtension。Godot 官方不内置(避免和闭源 SDK 绑定)。

提供:成就、统计、排行榜、云存档、创意工坊、好友、大厅/P2P 联机、Steam Input、DLC、内购、富存在(Rich Presence)……几乎整个 Steamworks。

### 2. 安装(真实集成)
1. **下载预编译版**:GodotSteam Releases 选对应 Godot 版本的 GDExtension 包
2. 解压到项目 `addons/godotsteam/`
3. **项目根放 `steam_appid.txt`**,内容 = 你的 App ID
   - 开发测试用 `480`(Spacewar,Valve 官方测试 app)
   - 上架后换成你自己的(在 Steamworks 后台申请,$100 一次性 Steam Direct 费用)
4. **Steam 客户端必须运行**且登录(SDK 通过它通信)
5. 重启 Godot,`Steam` 单例可用

### 3. 优雅降级模式(本 demo 核心)
```gdscript
var _has_steam := Engine.has_singleton("Steam")

func unlock_achievement(name):
    if not _has_steam:
        print("[no-steam] would unlock: ", name)   # no-op
        return
    var Steam = Engine.get_singleton("Steam")
    Steam.setAchievement(name)
    Steam.storeStats()
```
**为什么必须**:
- 开发时你不想每次都开 Steam
- itch.io / 自家商店版本没有 Steam
- demo 版可能不走 Steam
游戏逻辑只调 `wrapper.unlock_achievement("X")`,**不关心 Steam 在不在**。

### 4. 初始化 + 回调泵
```gdscript
var result = Steam.steamInitEx()
if result["status"] != 0:
    push_error(result["verbal"])

# 关键:Steam 回调要每帧手动 pump
func _process(_delta):
    Steam.run_callbacks()
```
忘了 `run_callbacks()` → 所有异步结果(排行榜查询、好友信息)永远不回来。

### 5. 成就
```gdscript
Steam.setAchievement("ACH_FIRST_WIN")
Steam.storeStats()                       # 必须 store 才提交!
var d = Steam.getAchievement("ACH_FIRST_WIN")   # {achieved: bool, ...}
```
成就的 **API Name** 在 Steamworks 后台定义(不是显示名)。`storeStats()` 不调的话本地解锁了但不上传。

### 6. 排行榜(异步)
```gdscript
Steam.findLeaderboard("HIGHSCORE")
var result = await Steam.leaderboard_find_result    # 等回调
# 拿到 handle 后:
Steam.uploadLeaderboardScore(score, keep_best, detail, handle)
```
排行榜也在后台定义。上传策略:`keep_best`(只留最高)或 `force_update`。

### 7. 云存档(Steam Cloud)
```gdscript
Steam.fileWrite("save.dat", bytes, bytes.size())
var data = Steam.fileRead("save.dat", Steam.getFileSize("save.dat"))
```
**或者**:啥都不做,把存档写在 `user://`,在 Steamworks 后台配置 **Auto-Cloud**(声明路径),Steam 自动同步 —— 配合 demo 22 的本地存档,0 代码上云。

### 8. 创意工坊(Workshop)
```gdscript
Steam.createItem(app_id, k_EWorkshopFileTypeCommunity)
# 上传:setItemTitle / setItemContent(文件夹) / submitItemUpdate
# 订阅的物品:getSubscribedItems → getItemInstallInfo → load
```
用户做的 mod / 关卡上传共享,你的游戏运行时加载订阅的内容目录。

## 导出到 Steam 的流程

1. GodotSteam 版 Godot 导出(用它编译的 export templates,或预编译版自带)
2. 导出产物 + Steamworks SDK 的 `steam_api64.dll`(Win)/`.so`(Linux)/`.dylib`(Mac) 一起打包
3. 用 **SteamPipe**(`steamcmd`)上传到你的 App depot
4. Steamworks 后台设置 launch options、成就、排行榜
5. 走审核 → 发布

CI 上传可参考 demo 19 的 secrets 模式(`STEAM_CONFIG_VDF` 避开 2FA)。

## 改造练习

1. **进度型成就**:`Steam.setStat("kills", n)` + 后台配 "击杀 100 解锁",Steam 自动判定。
2. **真实排行榜**:补全 `await leaderboard_find_result` → upload → download top 10 显示。
3. **Auto-Cloud**:把 demo 22 的 `user://saves/` 配进 Steamworks Auto-Cloud,免代码同步。
4. **好友富存在**:`Steam.setRichPresence("status", "在第 3 关")`,好友列表能看到。
5. **DLC 检测**:`Steam.isDLCInstalled(dlc_id)` 解锁付费内容。
6. **P2P 联机**:用 `SteamMultiplayerPeer`(GodotSteam 提供)替代 demo 17 的 ENet,走 Steam 中继,免端口转发。

## 易踩坑

- **steam_appid.txt 没放** → init 失败。开发用 480。
- **Steam 客户端没开/没登录** → init 失败。
- `setAchievement` 后**忘记 `storeStats()`** → 看着解锁了重启就没。
- `run_callbacks()` 每帧没调 → 异步结果石沉大海。
- App ID 用 480 时,成就/排行榜都是 Spacewar 的,**不能自定义**;要测自己的需要真 App ID。
- 导出忘了带 `steam_api64.dll` → 玩家端 init 失败崩溃。
- GodotSteam 版本必须**严格匹配** Godot 版本,错位直接加载失败。
- Mac 上 Steam overlay + Godot 偶有冲突,注意 entitlements 签名。
- 这个 wrapper 用了 `Engine.get_singleton("Steam")` 动态访问 —— 没装时 `has_singleton` 返回 false,所以 GDScript 不会因为找不到 `Steam` 类而报解析错误。**不要在脚本顶层直接写 `Steam.xxx`**,那样没装时整个脚本编译失败。
