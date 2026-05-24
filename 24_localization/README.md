# Demo 24 — Localization (i18n)

完整本地化:`tr()` + CSV + 运行时切换 locale,标签实时更新。**4 种语言**(en / zh / ja / es),自包含。

## 跑起来

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```

顶部 4 个按钮,每个按钮**用自己语种显示**(中文按钮就是"中文"两个字)。点哪个,整个 UI 立刻切。

## 学到什么

### 1. Godot 的本地化总线
```
strings.csv  ← 一行一 key,一列一 locale
    │
    │ (import 或本 demo 的运行时 parser)
    ▼
Translation 资源(每 locale 一个)
    │
    ▼
TranslationServer  ← 全局单例,管 locale + tr() 查表
    │
    ▼
tr("KEY")  ← 在代码任何地方
Label.text = "KEY"  ← + auto_translate → 自动转
```

### 2. CSV 格式
```csv
keys,en,zh,ja,es
GAME_TITLE,My Game,我的游戏,マイゲーム,Mi Juego
GREETING,"Hello, {name}!","你好,{name}!",...
```
- **第一列名字必须是 `keys`** 或 `key`(Godot 自动 import 才识别)
- 含逗号 / 换行的值用 `"` 包,内部 `"` 要写 `""`(标准 CSV)
- UTF-8 无 BOM

### 3. 两条路:导入 vs 运行时 parse

**A. 导入(官方推荐,本 demo 没用但要知道)**
1. 把 `strings.csv` 拖进项目
2. Godot 弹出 Import 面板,选 `Translation`,Reimport
3. 自动生成 `strings.en.translation`,`strings.zh.translation` 等
4. `Project Settings → Localization → Translations` 把这些 .translation 加进列表

启动后 TranslationServer 自动有这些翻译,**0 代码**。

**B. 运行时 parse(本 demo)**
```gdscript
var locales = I18n.install("res://strings.csv")
# 内部:parse CSV → 构造 Translation → TranslationServer.add_translation()
```
好处:`.csv` 直接随项目走,无需在编辑器配 Import 设置;团队成员 clone 下来就能跑。

### 4. tr() 怎么用
```gdscript
label.text = tr("HELLO")                      # 简单查表
label.text = tr("GREETING").format({"name": "Yolo"})   # 带变量
```
**格式化用 `.format(dict)`**,在翻译文里写 `{name}` `{hours}`。比 `%s` 灵活,适应不同语序(中英文形容词/名词顺序不同)。

### 5. UI 文本两种"绑定方式"

**A. Label.text = key + auto_translate**(本 demo 的主要做法)
```
[node name="Title" type="Label"]
text = "GAME_TITLE"           # 直接写 key
```
Godot 4 默认 `auto_translate_mode = INHERIT`(继承父),根 Control 默认 ALWAYS。**只要 text 是个已注册的 key,渲染时自动替换**。

切 locale 时调:
```gdscript
propagate_notification(NOTIFICATION_TRANSLATION_CHANGED)
```
让所有 Control 重新评估自己的 text。

**B. 代码里 tr()**(动态拼接、参数替换)
```gdscript
stats.text = tr("GREETING").format({"name": "Yolo"})
```
切 locale 后**自己重新调一次**,因为没人替你重算这个表达式。

### 6. 切语言
```gdscript
TranslationServer.set_locale("zh")
TranslationServer.set_locale("zh_CN")      # 也认地区后缀
TranslationServer.get_locale()              # 当前
TranslationServer.get_loaded_locales()      # 全部可用
```

### 7. 用其他语种显示当前语种名
```gdscript
TranslationServer.translate_to(target_locale, "LANG_NAME")
```
**不切换全局 locale**,只查"在 X 语言下,LANG_NAME 是什么"。本 demo 用它做语言选择按钮 —— "中文" 按钮永远是中文,不会被切到日文界面里变成 "中国語"。

### 8. fallback locale
```ini
[internationalization]
locale/fallback="en"
```
某个 key 在当前 locale 没翻译时,**回退到 en**。没 fallback 就显示 key 本身(`"GAME_TITLE"`)。

## 字体陷阱

Godot 默认字体**只覆盖拉丁字符**!切到 zh / ja 立刻看到方块。

解决:
1. 下一个支持中日韩的字体,例如 [Noto Sans CJK](https://github.com/notofonts/noto-cjk)
2. Project Settings → GUI → Theme → Custom Font,或者:
3. 编辑一个 Theme 资源 → 给 Label / Button 的 default font 设成 NotoSansCJK
4. 字体导入设置里:多脚本一起开,Subpixel 关掉(大字号没影响)

本 demo **没配字体**,跑起来中文/日文会是方块 —— 这是预期,展示 i18n 逻辑层。配字体的步骤:
```
1) 在编辑器 FileSystem 拖入 NotoSansCJK-Regular.otf
2) New Resource → Theme → 保存 res://theme.tres
3) Theme 编辑器 → Default Font → 选刚才的字体
4) Project Settings → GUI → Theme → Custom: res://theme.tres
```

## 与 Flutter easy_localization 的对照

| | Flutter easy_localization | Godot Localization |
|---|---|---|
| 文件 | `assets/translations/zh.json` 每语种一文件 | `strings.csv` 一个文件 N 列 |
| 取值 | `'KEY'.tr()` | `tr("KEY")` |
| 参数 | `'GREETING'.tr(namedArgs: {'name': x})` | `tr("GREETING").format({"name": x})` |
| 切换 | `context.setLocale(Locale('zh'))` | `TranslationServer.set_locale("zh")` |
| 自动刷新 | Widget 重建(需要 context.locale) | propagate_notification |

你在 booking-admin 那套经验直接迁过来用。

## 改造练习

1. **加 PO/POT 流程**:`Project → Tools → Generate POT`,导出 .pot 给翻译人员用 Poedit 翻,生成 .po,导回。比 CSV 协作更专业。
2. **保存 locale**:用 demo 06 / 22 的存档系统把用户选的语言写进 `user://locale`,下次启动自动恢复。
3. **复数 / 性别**:`tr_n("ITEMS", "ITEMS_PLURAL", count)`(Godot 也支持)。CSV 里给两个 key。
4. **从远程加载**:游戏发布后想加新翻译?在 demo 16 的 HTTPRequest 拉一个 CSV,运行时 install。
5. **字体子集**:中文字体太大(20MB)?用 [Font Subsetter](https://everythingfonts.com/subsetter) 只保留 CSV 里实际用到的字符,缩到 200KB。
6. **RTL(阿拉伯语)**:Godot Control 有 `layout_direction = LAYOUT_DIRECTION_RTL`,所有 box 容器自动镜像。

## 易踩坑

- **第一列必须是 `keys`**(import 路径必读)或代码 parser 兼容,本 demo 的 parser 任何名字都行,但用 `keys` 与官方对齐最好。
- `.format` 的占位符用 `{key}` 大括号,**不是 `%s`**。混用会 silently 不替换。
- 切了 locale 但 UI 没变?试 `propagate_notification(NOTIFICATION_TRANSLATION_CHANGED)`。或检查 Control 的 `auto_translate_mode` 是否为 ALWAYS。
- 字体不支持目标语种 → 方块。先看导出包字体设置。
- CSV 里逗号被 split 错 → 用 `"..."` 包整段。本 demo 的 parser 实现了简单的引号转义。
- `tr("KEY")` 找不到 → 默认返回 `"KEY"` 字符串本身(不报错)。debug 时看到 "KEY" 出现在 UI 上就知道翻译缺失。
- 多语种 import 后,在 Project Settings 里 **没把 .translation 加进 Translations 列表** → TranslationServer 不知道它们存在。
- 自动 import 在 macOS / Linux 上对 CSV 行尾敏感:用 LF 别用 CRLF(Windows 自带记事本会写 CRLF;VSCode 保存时切 LF)。
