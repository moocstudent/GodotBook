# Demo 35 — Dialogue System (分支对话)

数据驱动的对话系统:JSON 定义对话树,打字机逐字显示,分支选项,条件跳转(金币不够的选项灰掉),状态记录(buy 后设 `has_sword`)。

## 跑起来

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```

- 数字键 **1-9** 选选项,**空格/回车** 跳过打字机
- 买剑选项需要 50 金币(初始 60),买了后状态栏显示 `has_sword`

## 学到什么

### 1. 对话即数据(不写死在代码)
```json
{
  "start": "intro",
  "nodes": {
    "intro": {
      "speaker": "商人",
      "text": "需要什么?",
      "choices": [
        { "text": "买剑", "next": "shop", "require_gold": 50, "set": {"has_sword": true} },
        { "text": "离开", "next": "leave" }
      ]
    }
  }
}
```
**好处**:策划改对话不用碰代码,翻译人员只翻 JSON,可以可视化编辑器生成。

### 2. 数据与 UI 解耦
- `DialoguePlayer`(纯逻辑,RefCounted):管当前节点、状态、选择
- `main.gd`(UI):打字机、按钮、输入
互不依赖。换个 UI 皮肤不动逻辑;单元测试 DialoguePlayer 不需要 UI。

### 3. 对话节点驱动
```gdscript
dp.current_node()        # {speaker, text, choices}
dp.available_choices()   # 当前可选项
dp.pick(index)           # 选择 → 跳到 next,执行 set/扣费
dp.is_finished()         # choices 空 = 结束
```

### 4. 条件选项
```gdscript
func choice_enabled(choice):
    if choice.has("require_gold") and gold < choice.require_gold:
        return false
    return true
```
不满足的选项**显示但禁用**(灰掉 + 提示),比直接隐藏更好 —— 玩家知道"有这个选项,但我钱不够"。

### 5. 状态(blackboard)
```gdscript
if choice.has("set"):
    for k in choice.set:
        state[k] = choice.set[k]    # has_sword = true
```
对话能改游戏状态(给物品、推进任务)。反过来后续节点可以读 `state` 决定显示什么(练习 1)。

### 6. 打字机效果
```gdscript
func _process(delta):
    _shown_chars += TYPE_SPEED * delta
    body.text = _full_text.substr(0, int(_shown_chars))
```
逐字显示。空格跳过 = 直接 `body.text = _full_text`。RichTextLabel 支持 BBCode,可以做 `[shake]` `[wave]` `[color]` 富文本。

### 7. 接 i18n(配 demo 24)
对话文本可以是翻译 key:`"text": "MERCHANT_GREETING"`,显示时 `tr(node.text)`。多语言对话直接用上 demo 24 的 CSV。

## 生产推荐:Dialogic 插件

手搓适合学。真实项目用 **[Dialogic](https://github.com/dialogic-godot/dialogic)**(Godot 最流行的对话插件):
- 可视化时间线编辑器
- 立绘 / 表情 / 背景切换
- 内置打字机、音效、变量、条件
- 角色资源管理
- 导出/导入翻译

或 **Ink**(inkle 的叙事语言,有 Godot 集成),适合超大型分支叙事。

## 改造练习

1. **条件显示节点**:节点加 `"condition": "has_sword"`,只在 state 满足时可达。
2. **立绘**:speaker 旁显示角色头像,根据 `"portrait"` 字段切换表情。
3. **变量插值**:文本里 `"你好 {player_name}"`,用 `.format(state)` 替换。
4. **打字音效**:每显示一个字符播一个 "嘀" 声(配 demo 09)。
5. **历史回溯**:记录走过的节点,加"回看"功能。
6. **接存档**:把 `state` 存进 demo 22 的存档,记住玩家的对话选择(影响后续剧情)。
7. **BBCode 特效**:重要词用 `[wave]` `[shake][color=red]`,RichTextLabel 自动动画。

## 易踩坑

- JSON 里**中文逗号 / 引号**会 parse 失败。用英文标点,文本内容才用中文。
- `JSON.parse_string` 失败返回 null,记得检查 `typeof(...) == TYPE_DICTIONARY`。
- 打字机用 `_process`(每帧),选项在打字**结束后**才显示,否则玩家能选还没读到的选项。
- `substr(0, n)` 按字符数,中文也是一字符一格(UTF-8 在 Godot String 里按 codepoint),没问题。
- 选项按钮的 `pressed.connect` 在循环里要用 `var idx := i` 捕获当前值,否则闭包捕获的是循环结束后的 i。
- 节点 id 拼错(`next` 指向不存在的节点)→ `current_node()` 返回空 → 对话卡死。加校验或 fallback。
- RichTextLabel 要 `bbcode_enabled = true` 才解析标签,否则 `[wave]` 当普通文字显示。
