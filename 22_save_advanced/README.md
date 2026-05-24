# Demo 22 — Save 系统进阶

在 demo 06 基础上做"真实游戏会用"的存档:**多 slot、加密、版本迁移链、云同步接口**。

## 跑起来

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```

- 改 name / +/- score / level up,然后 **Save → slot N**
- **Load** 切槽,**Delete** 抹一个
- **↑Cloud / ↓Cloud**:推/拉到 demo 中的 `https://your-backend.example.com/saves`(不存在,会失败 —— 但完整跑了 PUT/GET 流程,看 Log 就知道客户端做了什么)

## 学到什么

### 1. 多 slot 路径模式
```
user://saves/
├── slot_0.sav          ← 加密
├── slot_1.json         ← 明文
└── slot_2.sav
```
路径函数:
```gdscript
static func slot_path(slot: int, encrypted: bool) -> String:
    var ext = ".sav" if encrypted else ".json"
    return "user://saves/slot_%d%s" % [slot, ext]
```
读取时**两种都试**(`slot_exists` 用 OR),让玩家无痛切换是否加密。

### 2. FileAccess.open_encrypted_with_pass
```gdscript
var file := FileAccess.open_encrypted_with_pass(
    path, FileAccess.WRITE, password
)
file.store_string(JSON.stringify(data))
```
Godot 内部用 **AES-256**。读时同样密码反向。

**这只防小白**:密码硬编码在 GDScript 里,任何人 grep 一下就能拿到。真要防作弊,服务器权威(demo 17)或者远程校验。

### 3. 版本迁移链:**累加,不覆盖**
```gdscript
static func migrate(data: Dictionary) -> Dictionary:
    var v = int(data.get("version", 1))
    if v < 2:
        data["settings"] = {...}      # v1 没有 settings
        data["inventory"] = []
        v = 2
    if v < 3:
        data["flags"] = {}            # v2 没有 flags
        data["playtime_sec"] = 0.0
        v = 3
    # ... v < 4 ...
    data["version"] = v
    return data
```
**规则**:
- 永不删旧分支(v1 玩家两年后回来 load,代码必须还能升)
- 每个 if 内只**加字段或转换**,不要删
- 升级是单向:v3 → v1 不要做(就让老客户端没法 load 新存档,简单)

### 4. 默认值兜底
```gdscript
var defaults := default_data()
for key in defaults.keys():
    if not data.has(key):
        data[key] = defaults[key]
```
**任何字段缺失** —— 不管是迁移漏了还是玩家手改了 JSON —— 都用 default 补。**永不**直接 `data["x"]` 没检查就用。

### 5. 上次保存时间戳
```gdscript
data["last_modified"] = Time.get_datetime_string_from_system()
# "2026-05-19T14:32:08"
```
ISO 8601 字符串,**直接字典序比较就能比时间先后**(YYYY-MM-DD 的好处)。云同步冲突解决靠这个字段。

### 6. 云同步:简版协议
```
PUT /saves/{slot}     body=JSON         200 = OK
GET /saves/{slot}                       200 = JSON
DELETE /saves/{slot}                    200 = OK
```
认证:`Authorization: Bearer <token>` 头。Token 怎么来?
- 微信 / Steam / Apple 登录(平台 SDK)
- 自家邮箱密码
- 匿名:UUID 存 user://,首次启动注册

冲突策略(本 demo 用了**最简的**):
```gdscript
if local.last_modified >= remote.last_modified:
    skip                     # 本地新,不覆盖
else:
    overwrite with remote
```
更稳的方案:**字段级三方合并**。需要服务器存档历史。

### 7. 加压缩(本 demo 没用但要知道)
```gdscript
var file := FileAccess.open_compressed(
    path, FileAccess.WRITE, FileAccess.COMPRESSION_FASTLZ
)
```
- `COMPRESSION_FASTLZ`:快,压缩率一般
- `COMPRESSION_ZLIB`:慢,压缩率好
- `COMPRESSION_ZSTD`:现代,最好的折中
玩家自己玩的存档不太需要压(几 KB),云端上传时压一下省流量。

## 完整对比 demo 06 vs 22

| | demo 06 | demo 22 |
|---|---------|---------|
| Slot | 1 | 3 |
| 加密 | 无 | AES-256 可选 |
| 版本 | v1/v2 | v1/v2/v3 |
| 云同步 | 无 | PUT/GET + 冲突解决 |
| 错误处理 | 简单 push_warning | 全链路 try/兜底 |
| 文件路径 | 写死 | 工厂方法 |

## 改造练习

1. **自动存档**:Timer 每 60s 触发 `save(0, ...)`,加 `auto_save` 字段,UI 显示"已自动存"。
2. **快速槽位 vs 手动**:slot 0 = "auto",slot 1-3 = "manual"。
3. **JSON Schema 校验**:写一个 `validate(data) -> Array[String]` 返回所有不合法字段,在 save 前过一遍。
4. **加密升级**:把密码改成由"机器 ID + 用户 ID"哈希,这样不同机器存档不能互通(防共享号)。
5. **真做后端**:用 Python FastAPI + SQLite,3 个 endpoint(PUT/GET/DELETE),20 行代码。
6. **Steam Cloud**:不用自己写,把存档都写在 `user://` 下,Steam 会自动同步(配置 .vdf 描述路径)。

## 易踩坑

- `FileAccess.open_encrypted_with_pass` 的密码**改了之后**,老存档**全部读不出来**。永远向前兼容:发布后绝不改密码,要改也要走"读老解 → 新密重写"流程。
- 加密文件**不可压缩**(熵已经最大)。要同时压缩+加密?先压后加密。
- `last_modified` 字符串比较 → 必须都是 UTC 或都是本地 ISO,**不要混**。生产建议用 unix epoch int:`Time.get_unix_time_from_system()`。
- `JSON.stringify` 把 `Vector2` 转成 `"(1, 2)"` 字符串,**load 回来要自己 parse**。本 demo 没存 Vector2 所以没问题。
- 多个 Godot 实例(如 demo 17 调试)**共享 user://**,会互踩存档。给 slot 加进程后缀或用 `--user-data-dir` 启动参数隔离。
- 云同步**网络抖动**:中途断网 → 本地写盘 OK,云端写失败 → 下次 load 会以为本地是最新。要在云端记录"待重传"标记。
- `CONNECT_ONE_SHOT` 在 4.x 写法:`signal.connect(handler, CONNECT_ONE_SHOT)`,不是 3.x 的字符串。
