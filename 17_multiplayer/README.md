# Demo 17 — Multiplayer (ENet)

最小可玩的多人:一台机上同时开两个 Godot 窗口,一个 Host,一个 Join。WASD 控制各自方块,所有人同步看到。**完整 HighLevel MultiplayerAPI** + `MultiplayerSpawner` + `MultiplayerSynchronizer`。

## 跑起来(两个窗口)

```powershell
# 窗口 A:
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
# 弹出后点 [Host]

# 窗口 B (新开终端):
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
# 弹出后点 [Join]
```

> **同机调试小技巧**:在编辑器 **Debug → Run Multiple Instances → 2** ,F5 直接起两个窗口。

要让别的电脑连进来:把 Host 的 IP(局域网内 `ipconfig` 找)填到 Client 的 Host 字段。**公网**需要端口转发或 NAT 穿透(不在本 demo 范围)。

## 三大组件

```
ENetMultiplayerPeer            ← 传输层:UDP 可靠/不可靠包,内置加密
MultiplayerAPI                 ← 高层,在 multiplayer 单例上,管理 peer 信号
MultiplayerSpawner             ← 节点。监视一个父节点,server 在那里 add_child,自动广播给所有 client 复刻
MultiplayerSynchronizer        ← 节点。挂在每个对象下,声明哪些属性要同步,以及谁有权改
```

## 学到什么

### 1. 启动一个 host
```gdscript
var peer := ENetMultiplayerPeer.new()
peer.create_server(12345, 8)            # 端口, 最大连接数
multiplayer.multiplayer_peer = peer
# 自己永远是 peer id 1(server 的固定 id)
```

### 2. 启动一个 client
```gdscript
var peer := ENetMultiplayerPeer.new()
peer.create_client("127.0.0.1", 12345)
multiplayer.multiplayer_peer = peer
# 连上后被 server 分配一个 > 1 的 unique id
```

### 3. 监听 5 个核心信号
```gdscript
multiplayer.peer_connected.connect(_on_peer_connected)
multiplayer.peer_disconnected.connect(_on_peer_disconnected)
multiplayer.connected_to_server.connect(_on_connected_to_server)
multiplayer.server_disconnected.connect(_on_server_disconnected)
multiplayer.connection_failed.connect(_on_connection_failed)
```
- 前两个 **server 和 client 都会收到**(client 也能知道新 peer 加入)
- 后三个**只有 client 收到**

### 4. MultiplayerSpawner 的契约
```
[node name="Spawner" type="MultiplayerSpawner" parent="World"]
_spawnable_scenes = PackedStringArray("res://player.tscn")
spawn_path = NodePath("../Players")
spawn_limit = 0       # 0 = 不限制
```
- `_spawnable_scenes`:**白名单**,只有列出的场景能通过本 spawner 被复制
- `spawn_path`:被监视的节点。server 在这个节点下 `add_child()` → spawner 自动把对应场景在所有 client 复刻出来
- **客户端绝不该自己 `add_child`** —— 那会本地生成一份"幽灵节点",不被同步

### 5. MultiplayerSynchronizer 的契约
```
[sub_resource type="SceneReplicationConfig" id="repl_cfg"]
properties/0/path = NodePath(".:position")
properties/0/spawn = true               # 生成时也带值过去
properties/0/replication_mode = 1       # 1=Always, 2=OnChange, 0=Never
```
- 列出的属性会按 `replication_mode` 周期性广播
- **谁广播?** synchronizer 的 `multiplayer_authority` 设定的那个 peer
- 默认 authority = 1(server)。本 demo 显式 `$Sync.set_multiplayer_authority(owner_id)`,让"持有者"自己广播自己的位置(client-authoritative,适合学习,不抗作弊)

### 6. set_multiplayer_authority — 权威模型
```
Server-authoritative:  $Sync.set_multiplayer_authority(1)
  - 输入发给 server,server 移动,position 由 server 广播
  - 抗作弊但有延迟感,需要客户端预测 + 服务器校正

Client-authoritative:  $Sync.set_multiplayer_authority(player_peer_id)
  - 客户端直接改自己的 position,广播出去
  - 简单,低延迟,但客户端可以撒谎(瞬移、改属性)
```
本 demo 用的是 **Client-authoritative**,player.gd 里:
```gdscript
if $Sync.get_multiplayer_authority() != multiplayer.get_unique_id():
    return    # 别人的角色我不动
```

### 7. 节点名 = peer id 的小技巧
```gdscript
p.name = str(peer_id)
players_node.add_child(p, true)        # true = 让 name 在跨节点引用时唯一
```
后续:
- `players_node.get_node(str(peer_id))` 找回对应玩家
- `$Sync.set_multiplayer_authority(name.to_int())` 在 player.gd 里推断主人

### 8. RPC(Remote Procedure Call)
本 demo 没用,但要知道:
```gdscript
@rpc("any_peer", "call_remote", "reliable")
func say_hello(msg: String):
    print(msg)

# 远端调用:
say_hello.rpc("hi from %d" % multiplayer.get_unique_id())
```
- `any_peer` / `authority` 谁能调
- `call_remote` / `call_local` 自己跑不跑
- `reliable` / `unreliable` 丢包重传?
- `unreliable_ordered` 不重传但保序

## 一台机器双开调试

最快:**Debug → Run Multiple Instances → 2** 之后 F5。Godot 自动开两个窗口,共享同一份代码,改完立刻热重载。

命令行手动开:
```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path . --position 0,0     &
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path . --position 920,0
```

## 改造练习

1. **加聊天**:用 RPC `@rpc("any_peer", "call_remote") func say(msg)`,所有人广播显示。
2. **服务器权威**:player.gd 改成"客户端发输入 → server 算 position → 自动广播",学习预测/对账。
3. **延迟模拟**:`peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_UNRELIABLE` + 自己加 200ms 延迟,看插值。
4. **房间号**:Host 时生成 6 字符 code,Client 输 code 自动找 IP(配合 demo 16 的 HTTP API,后端做个 KV)。
5. **场景切换同步**:server 切场景时所有 client 跟着切 —— 用 RPC 广播 `change_scene` 信号,各端本地 `get_tree().change_scene_to_packed(...)`。
6. **WebSocketMultiplayerPeer**:把 ENet 换成 WebSocket,这样可以从 HTML5 export 加入游戏。

## 易踩坑

- **客户端自己 `add_child` 玩家** → 本地有一份,server 不知道,看着像同步但其实是幽灵。永远让 server spawn。
- `MultiplayerSpawner.spawn_path` 错指 → 哪都不生成,且**不报错**。仔细检查 NodePath。
- Synchronizer 的 `replication_config` 里属性 path 写错 → 不同步,**不报错**。Godot 编辑器有 visual 编辑器,优先用它。
- `set_multiplayer_authority` 在 **add_child 之前**调一般无效;**先入树后改 authority**。本 demo 在 `_ready()` 里改是稳的。
- `peer_connected` 在 server 上**对每个加入的 client 都触发**,但 client 上**也会对 server (id=1) + 其他已加入 peer 触发**。注意这意味着加入第二个 client 时第一个 client 也会收到 peer_connected。
- ENet 默认走 UDP,公司/咖啡馆 WiFi 可能丢 UDP → 局域网测试可以,公网得用 WebSocket / WebRTC。
- 端口 `12345` 被占? `netstat -ano | findstr 12345`,换一个。
- 关闭某个窗口 → 看另一侧 `peer_disconnected` 是否触发并清掉对应玩家;没清就有"僵尸方块"。
