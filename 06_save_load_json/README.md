# Demo 06 — Save / Load (JSON)

存档读档面板:改名字、加分、升级,Save 写盘,Load 读盘,Delete 抹掉。展示**生产级**的存档骨架:`user://`、版本号、迁移、容错。

## 跑起来

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```

界面上会显示存档**绝对路径**,可以直接用文件管理器打开看 JSON 内容。

## 学到什么

### 1. `user://` 是什么?
Godot 抽象路径协议:

| 协议 | 含义 | 可写? |
|------|------|--------|
| `res://` | 项目资源(打包到 `.exe`/`.apk` 里) | **运行时只读** |
| `user://` | 玩家数据目录(每个项目独立) | ✓ 可写 |

`user://save.json` 实际落到:
- Windows:`%APPDATA%\Godot\app_userdata\<项目名>\save.json`
- macOS:`~/Library/Application Support/Godot/app_userdata/<项目名>/`
- Linux:`~/.local/share/godot/app_userdata/<项目名>/`
- Android/iOS:app 沙盒(玩家看不到)

**永远别尝试写 `res://`**,导出后是只读包文件,运行时写入会失败。

### 2. FileAccess(Godot 4)
Godot 3 是 `var f = File.new(); f.open(...); ...; f.close()`。
Godot 4 改成静态工厂 + RAII:

```gdscript
var file := FileAccess.open("user://save.json", FileAccess.WRITE)
file.store_string(JSON.stringify(data, "\t"))
# file 离开作用域自动 close
```

读:
```gdscript
var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
var text := file.get_as_text()
```

打开失败:`FileAccess.open` 返回 `null`,具体错误用 `FileAccess.get_open_error()` 拿。

### 3. JSON 序列化
```gdscript
var text := JSON.stringify(data, "\t")     # 带缩进,可读
var parsed: Variant = JSON.parse_string(text)
if typeof(parsed) != TYPE_DICTIONARY:
	# 损坏
```
- `JSON.parse_string` 失败返回 `null`(不是异常)
- Dictionary 和 Array 可以无缝来回
- 但 **GDScript 对象 / Vector2 / Color 不能直接 JSON 化**,需要先 `to_dict()`/`{x: ..., y: ...}` 自己转

### 4. 版本号 + migrate()
**这是真正的核心**。游戏在卖出后还会更新,玩家硬盘里的存档可能是任何老版本。

```gdscript
const CURRENT_VERSION := 2

static func migrate(data: Dictionary) -> Dictionary:
	var v: int = data.get("version", 1)
	if v < 2:
		data["settings"] = {...}    # v1 没有 settings
		data["inventory"] = []
		v = 2
	# 后续版本继续 if v < 3: ...
	data["version"] = v
	return data
```

模式:**每升版本写一段 if,顺序累加**。绝不删旧分支。

### 5. 默认值兜底
```gdscript
var defaults := default_data()
for key in defaults.keys():
	if not data.has(key):
		data[key] = defaults[key]
```
玩家手改 JSON 删掉某字段也不会崩。"防御性反序列化"。

### 6. RefCounted + class_name + static
```gdscript
extends RefCounted
class_name SaveManager

static func save(...): ...
```
- `class_name SaveManager`:全局类型注册,任何脚本可以 `SaveManager.save(...)` 直接调
- `static func`:不需要实例,纯工具函数
- 这是 GDScript 里"工具类 / 模块"的标准写法

更复杂的项目会做成 **Autoload 单例**(Project → Project Settings → Autoload),引用 `SaveManager.method()` 但是是实例,可以发信号。

## 改造练习

1. **多存档槽**:把 `SAVE_PATH` 换成 `"user://save_%d.json" % slot`,做 3 个槽位 UI。
2. **加密 / 压缩**:`FileAccess.open_compressed(...)` 或 `FileAccess.open_encrypted_with_pass(...)`,防止玩家直接改 JSON 作弊。
3. **改成二进制**:`file.store_var(data)` / `file.get_var()` 用 Godot 内置 Variant 序列化,更小更快,但**不能跨大版本**(格式可能变)。
4. **自动存档**:加一个 `Timer`,30 秒触发一次 `_on_save()`。
5. **存 Vector2/Color**:存的时候转 `{x: vec.x, y: vec.y}`,读的时候 `Vector2(d.x, d.y)`,体会"GDScript 类型 vs JSON 类型"边界。
6. **Cloud Save**:把 `user://` 内容通过 HTTPRequest 同步到自家服务器或 Firebase。

## 易踩坑

- `JSON.stringify(data)` 不传第二个参数会输出一长行无空白 —— 调试看着累,生产环境为了体积反而想要。
- Dictionary 的 key 在 JSON 里**永远是 string**。`data[1] = "x"` 存盘读回来会变成 `data["1"]`。
- `FileAccess.file_exists("user://save.json")` 在没存过的初次启动**就是 false**,要在 `load_data` 里处理。
- 改 `default_data()` 的字段名时,**别忘了同步 migrate()**,否则老存档 load 后字段还是旧名字。
- Android 平台 `user://` 在卸载 app 后会被清空,提醒玩家不要依赖它作为云档。
