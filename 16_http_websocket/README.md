# Demo 16 — HTTP + WebSocket

左半屏:`HTTPRequest` 拉一个 JSON API,自动美化输出。
右半屏:`WebSocketPeer` 连公网 echo 服务,发什么收什么。

## 跑起来

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```

**需要网络**。默认 URL:
- HTTP:`https://jsonplaceholder.typicode.com/todos/1` —— JSON API 的"hello world"
- WebSocket:`wss://echo.websocket.events` —— 任何文本原样回弹

## 学到什么

### 1. HTTPRequest 的工作流
```gdscript
var http := HTTPRequest.new()
add_child(http)                                # 必须挂到树
http.request_completed.connect(_on_done)

http.request(url, headers, HTTPClient.METHOD_GET, body)
```
- **必须 add_child** —— HTTPRequest 是 Node,不是普通对象,它内部要在树上跑异步
- 一个 HTTPRequest 一次**只能跑一个请求**,要并发请求开多个实例
- 没有 retry/progress 自带,要自己写

回调签名固定:
```gdscript
func _on_done(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
    if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
        var text = body.get_string_from_utf8()
        var data = JSON.parse_string(text)
        ...
```

`result` 的常见值:
- `RESULT_SUCCESS = 0` 网络层成功(不代表 200,可能 404/500)
- `RESULT_TIMEOUT` 超时
- `RESULT_CANT_CONNECT` DNS / 路由
- `RESULT_TLS_HANDSHAKE_ERROR` HTTPS 证书

### 2. POST / Bearer / Body
```gdscript
http.request(
    "https://api.example.com/users",
    PackedStringArray([
        "Content-Type: application/json",
        "Authorization: Bearer " + token,
    ]),
    HTTPClient.METHOD_POST,
    JSON.stringify({"name": "Alice"})
)
```

### 3. 下载文件
```gdscript
http.download_file = "user://big.zip"
http.request(url)
```
HTTPRequest 自动写盘,不需要你接 `body`。配合 `request_completed` 拿状态。

### 4. WebSocketPeer 与 HTTPRequest 的对比
| | HTTPRequest | WebSocketPeer |
|---|---|---|
| 通信方向 | client → server,server 单次回 | 双向,持续 |
| 节点形态 | Node,挂树 | RefCounted,你自己 poll |
| 何时用 | REST API 拉/推数据 | 实时聊天、推送、游戏帧同步 |
| 状态机 | 没有,每次新请求 | CONNECTING → OPEN → CLOSING → CLOSED |

### 5. WebSocketPeer 的 poll 循环
```gdscript
var ws := WebSocketPeer.new()
ws.connect_to_url("wss://...")

func _process(_delta):
    ws.poll()                                  # 推进状态机、解析进来的包

    if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
        while ws.get_available_packet_count() > 0:
            var pkt := ws.get_packet()
            var msg := pkt.get_string_from_utf8()
            ...
```
**没事件机制**,要你自己每帧 poll。如果忘了 poll,连接卡 CONNECTING 永远不变。

### 6. 发送
```gdscript
ws.send_text("hello")    # TEXT frame
ws.send(PackedByteArray([0x01, 0x02]))   # BINARY frame
```

### 7. 关闭与重连
```gdscript
ws.close(1000, "bye")    # code 1000 = 正常关闭
# Re-connect:
ws = WebSocketPeer.new()
ws.connect_to_url(...)
```
**没有自动重连** —— 自己写带退避的循环。

### 8. TLS 证书
- `wss://` 自动启用 TLS,Godot 内置一组根证书
- 自签名服务器:`ws.connect_to_url(url, tls_options)`,`tls_options = TLSOptions.client_unsafe()` 跳过校验(**仅 dev**)
- 自定义 CA:`TLSOptions.client(cert_bundle)`

## 改造练习

1. **进度条**:用 `http.get_downloaded_bytes()` / `get_body_size()` 每帧更新一个 ProgressBar。
2. **并发 N 请求**:做个池,5 个 HTTPRequest 节点轮转。
3. **WebSocket 心跳**:每 30s `ws.send_text("ping")`,服务端不响应就断线重连。
4. **JSON-RPC**:自己实现 id 匹配,把"发一条等回一条"的 WebSocket 包装成 awaitable function。
5. **代理你自己的 backend**:把 URL 换成 `http://localhost:8080/...`,本地 Node/Python 后端测试。
6. **下载图片显示**:`http.download_file = "user://avatar.png"`,完成后 `Image.load("user://avatar.png")` → `ImageTexture` → `TextureRect.texture`。

## 实际项目里的封装(模式)

```gdscript
# net.gd  (Autoload 单例)
extends Node

func get_json(url: String) -> Variant:
    var http := HTTPRequest.new()
    add_child(http)
    http.request(url)
    var result = await http.request_completed
    http.queue_free()
    var body: PackedByteArray = result[3]
    return JSON.parse_string(body.get_string_from_utf8())

# 使用:
var data = await Net.get_json("https://...")
```
**`await` + signal** 让 HTTP 看起来同步,代码顺。这是 Godot 4 异步 API 的标准用法。

## 易踩坑

- HTTPRequest **不挂进 SceneTree** → `request()` 立即返回错误。
- `request_completed` 的 `result` 是网络层,**不是 HTTP 状态码**。要看 `response_code`。
- WebSocket **忘了 poll** → state 永远卡在 CONNECTING。
- `wss://` 在自己的开发机上没问题,**导出到 HTML5 webgl 上跑**有跨域限制,需要服务端配 CORS。
- WebSocketPeer 在 close 后**不能复用**,得 new 一个新实例。
- 大 body 反复 `get_string_from_utf8` 会复制内存,4MB 以上考虑用 `String.parse_string()` 或流式处理。
- 公共 echo / placeholder 服务可能限速。**生产环境别依赖**。
