# Demo 38 — Steam P2P 联机

用 **SteamMultiplayerPeer** 替代 demo 17 的 ENet:走 Steam 中继 / NAT 穿透,玩家**无需端口转发**就能联机,还能用 Steam 大厅匹配。**接口与高层 MultiplayerAPI 完全一致**——游戏逻辑一行不改,只换底层 peer。没 GodotSteam 时降级到 ENet 本地回环。

## 跑起来

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```

没装 GodotSteam → 顶部显示 "ENet(本地回环)"。Host / Join 走 127.0.0.1 测试(开两个窗口)。装了 GodotSteam + 配好 App ID → 走真实 Steam 大厅。

## 学到什么

### 1. 为什么需要 Steam P2P
demo 17 的 ENet 问题:
- **公网联机要端口转发** —— 玩家家用路由器后面,默认连不进来
- IP 暴露(可被 DDoS)
- 没有匹配系统(要自己搭服务器交换 IP)

Steam P2P 解决:
- **Steam 中继(SDR,Steam Datagram Relay)**:流量走 Valve 的服务器中转,NAT 穿透
- **大厅(Lobby)匹配**:`createLobby` / `joinLobby`,好友列表直接 join
- 加密、隐藏真实 IP

### 2. 关键洞察:接口不变,底层可换
Godot 的高层 `MultiplayerAPI` 是**传输无关**的:
```gdscript
multiplayer.multiplayer_peer = peer    # peer 可以是任意实现
```
peer 的实现可以是:
- `ENetMultiplayerPeer`(UDP,demo 17)
- `WebSocketMultiplayerPeer`(可从 HTML5 连)
- `WebRTCMultiplayerPeer`(浏览器 P2P)
- `SteamMultiplayerPeer`(GodotSteam 提供,Steam 中继)
- `OfflineMultiplayerPeer`(单机)

**换 peer,上层 RPC / MultiplayerSpawner / Synchronizer 全部照常工作**。demo 17 的所有代码套到 Steam 上零改动。这是 Godot 网络设计的精髓。

### 3. Steam 大厅 + P2P 流程
```gdscript
# Host:
Steam.createLobby(LOBBY_FRIENDS_ONLY, 4)        # 异步
# 回调 lobby_created:
var peer = SteamMultiplayerPeer.new()
peer.create_host(0)
multiplayer.multiplayer_peer = peer

# Client:
Steam.joinLobby(lobby_id)                        # 异步
# 回调 lobby_joined:
var owner = Steam.getLobbyOwner(lobby_id)
var peer = SteamMultiplayerPeer.new()
peer.create_client(owner, 0)
multiplayer.multiplayer_peer = peer
```
之后 `multiplayer.peer_connected` 等信号与 ENet 一模一样。

### 4. 大厅类型
```
LOBBY_PRIVATE        私密,只能邀请
LOBBY_FRIENDS_ONLY   好友可见可加
LOBBY_PUBLIC         公开,匹配列表可搜
LOBBY_INVISIBLE      不可见(用于匹配后台)
```

### 5. 找大厅
```gdscript
Steam.addRequestLobbyListDistanceFilter(LOBBY_DISTANCE_FILTER_WORLDWIDE)
Steam.requestLobbyList()
# 回调拿到 lobby 列表 → 显示房间浏览器
```
或者好友列表里直接 "Join Game"(Rich Presence,配 demo 29)。

### 6. 优雅降级(本 demo)
```gdscript
func host():
    if has_steam: _host_steam()
    else: _host_enet()         # 开发期 / 无 Steam 用 ENet 本地测
```
游戏逻辑只调 `net.host()` / `net.join()`,不关心底层。开发时用 ENet 双开窗口快速测,发布走 Steam。

## 前置(真实集成)
1. 装 **GodotSteam**(demo 28),含 `SteamMultiplayerPeer` 类
2. `steam_appid.txt`(480 测试用)
3. Steam 客户端运行
4. 双方都是好友 / 同大厅

## 改造练习

1. **房间浏览器**:`requestLobbyList` + 过滤,显示可加入的大厅列表。
2. **把 demo 17 搬过来**:demo 17 的 player.tscn + MultiplayerSpawner/Synchronizer 直接用,只把 peer 换成 Steam,验证"零改动"。
3. **好友邀请**:`Steam.inviteUserToLobby(friend_id, lobby_id)` + Rich Presence join(demo 29)。
4. **大厅元数据**:`Steam.setLobbyData(id, "map", "desert")`,房间浏览器显示地图/模式。
5. **WebRTC 版**:换 WebRTCMultiplayerPeer,做浏览器 P2P(需信令服务器交换 SDP)。
6. **专用服务器**:大型游戏用 dedicated server(SteamGameServer),而非 P2P host。

## 易踩坑

- `SteamMultiplayerPeer` 来自 GodotSteam,**没装就没这个类** → 本 demo 用 `ClassDB.instantiate("SteamMultiplayerPeer")` 动态创建避免脚本顶层引用编译失败。
- 大厅操作**异步**:`createLobby` 立即返回,真正的 id 在 `lobby_created` 回调里。别同步等。
- `Steam.run_callbacks()` 每帧必调,否则大厅/连接回调永远不来。
- P2P host 也是 peer id 1(和 ENet 一样的语义)。
- Steam 中继有少量延迟(多一跳),但换来 NAT 穿透,值得。
- 测试 P2P 需要**两个不同 Steam 账号**(或一个账号 + Steam 的 `-steamid` 多开,较麻烦)。本地开发用 ENet 降级最快。
- App ID 480 的大厅是公共的,可能撞到别人的测试。正式测用自己的 App ID。
- 上层逻辑(RPC/Spawner/Synchronizer)与 demo 17 完全一致 —— 这正是重点,别重复造轮子。
