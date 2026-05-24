# Demo 39 — Mod Support (运行时加载资源包)

运行时挂载 `.pck` / `.zip` 资源包给游戏加 mod。展示 `ProjectSettings.load_resource_pack`、数据合并(基础 + mod 覆盖/新增)、mod 清单扫描。

## 跑起来

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```

没 mod 时显示 3 个基础武器 + mod 目录路径。按 README 做个 mod pck 放进去,重启 → 物品列表变化。

## 学到什么

### 1. load_resource_pack
```gdscript
ProjectSettings.load_resource_pack("user://mods/cool.pck", true)
```
- 把 pck 里的文件**挂进 `res://` 虚拟文件系统**
- 第二参 `replace_files = true`:同名文件**覆盖**原版(改平衡、换贴图)
- `false`:只新增不覆盖
- `.zip` 也支持(同 API)

挂载后,`load("res://...")` / `FileAccess` 读到的就是合并后的虚拟文件系统。

### 2. Godot 的 .pck 是什么
就是 Godot 导出时把所有 `res://` 资源打包的那个文件(`.exe` 旁边的 `game.pck`)。你也可以**单独导出一个 pck** 只含 mod 内容:
- Project → Export → 任意预设 → **Export PCK/Zip** 按钮
- 只勾选要打包的文件 / 用 export filter

### 3. mod 加载流程
```gdscript
# 必须在读数据之前挂载!
func _ready():
    ModLoader.load_all()        # 扫 user://mods/*.pck 全挂上
    var items = ModLoader.load_items()  # 此时读到的是合并后数据
```
**顺序关键**:先挂载所有 pck,再读资源。挂载后挂的不会影响已经 load 的。

### 4. 数据合并策略
```gdscript
for k in mod_items:
    result[k] = mod_items[k]    # 同 id 覆盖(改属性),新 id 新增(加内容)
```
- **覆盖**:mod 改 `sword.damage` 从 10 → 20(平衡 mod)
- **新增**:mod 加 `laser_gun`(内容 mod)
多 mod 叠加:后加的覆盖先加的(注意加载顺序 = 优先级)。

### 5. mod 清单(mod.json)
真实 mod 系统每个 mod 带清单:
```json
{
  "id": "cool_weapons",
  "name": "酷炫武器包",
  "version": "1.2.0",
  "author": "modder123",
  "game_version": ">=1.0",
  "dependencies": ["base_framework"]
}
```
用来:显示 mod 列表、检查版本兼容、解析依赖加载顺序、启用/禁用。

### 6. 两类 mod
| 数据 mod | 代码 mod |
|---|---|
| json / png / 音频 | 含 `.gd` 脚本 |
| 安全 | **危险**(任意代码执行) |
| 改数值、换皮 | 加新机制、新 AI |

## ⚠️ 安全警告(重要)
`.pck` 里**可以包含 `.gd` 脚本**,挂载后这些脚本能被实例化执行 = **让玩家运行任意代码**。

风险:恶意 mod 删文件、偷数据、装病毒。

对策:
1. **只允许数据 mod**:加载后只读 json/png,绝不 `load()` mod 里的 .gd/.tscn(scene 也能挂脚本)
2. **白名单**:只 load 已知路径的特定类型
3. **创意工坊审核**:Steam Workshop(demo 28)有举报/审核
4. **沙箱**:Godot 没内置 GDScript 沙箱,真要执行不可信代码极难安全

商业游戏的"安全 mod"通常 = 纯数据 + 官方提供的有限脚本钩子。

## 做一个 mod(亲手试)

1. 新建临时 Godot 项目
2. 放 `mods_data/my_mod.json`:
   ```json
   { "items": { "sword": {"name":"传说之剑","damage":99,"color":"#ff4488"},
                "laser": {"name":"激光枪","damage":50,"color":"#44ffaa"} } }
   ```
3. Project → Export → 加预设 → **Export PCK/Zip** → `my_mod.pck`
4. 拷到本 demo 的 `user://mods/`(运行时状态栏显示绝对路径)
5. 重启 demo → 剑变传说之剑(覆盖)+ 多了激光枪(新增)

## 改造练习

1. **mod.json 清单**:每个 mod 读清单,UI 列出名字/作者/版本。
2. **启用/禁用**:UI 勾选框,只挂载启用的 mod,选择存 demo 22 存档。
3. **加载顺序**:拖拽排序 mod 优先级(后加覆盖先加)。
4. **贴图 mod**:mod 覆盖 `res://textures/sword.png`,demo 自动用新图(load_resource_pack replace)。
5. **依赖解析**:mod A 依赖 mod B → 拓扑排序决定加载顺序。
6. **热重载**:不重启,运行时挂载新 mod + 刷新数据(注意已 load 的资源不会变)。

## 易踩坑

- **挂载顺序**:`load_resource_pack` 必须在 `load()` 那些资源**之前**调。已经加载进内存的资源不受后续挂载影响。
- `replace_files` 默认 **true**(覆盖)。想纯新增设 false。
- pck 版本要匹配:用 Godot 4.3 导的 pck 在 4.2 引擎加载可能失败。
- mod 里的 `.import` 文件:贴图/音频需要对应的 `.import` 元数据一起打包,否则 load 失败。直接放 .json/.txt 这类无需 import 的最简单。
- **安全**:再说一遍,加载含脚本的 pck = 执行任意代码。数据 mod 安全,代码 mod 危险。
- `user://mods/` 目录首次不存在,要 `make_dir_recursive_absolute` 创建(本 demo 做了)。
- Web 导出(HTML5)的 `user://` 在浏览器 IndexedDB 里,放 mod 文件麻烦,mod 系统一般只在桌面端。
