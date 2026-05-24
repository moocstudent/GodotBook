# Demo 41 — Coin Dash(毕业作 / 整合 capstone)

一个**完整可玩**的平台小游戏:集齐 7 个金币、躲开岩浆、到达终点。计时 + 存最佳纪录。这是前面零散 demo 的"组装演示"——单个 demo 教一招,这里教**怎么把它们拼成游戏**。

## 跑起来

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```

- **WASD / 方向键** 移动,**空格** 跳
- 集齐全部金币(终点变亮)→ 踩上绿色终点过关
- 碰到**红色岩浆**失败
- **Esc** 暂停,**R** 随时重开
- 过关计时,破纪录会存盘(下次启动显示最佳)

## 整合了哪些 demo

| 来自 | 用在哪 |
|------|--------|
| [03 platformer](../03_platformer_2d/) | 玩家移动:重力 + 土狼时间 + 跳跃缓冲(`player.gd`) |
| [05 scene_instancing](../05_scene_instancing/) | 金币是实例化的 `coin.tscn`,Area2D 检测拾取 |
| [13 particles](../13_particles/) | 拾取时 CPUParticles2D 金色爆开 |
| [09 audio](../09_audio/) | 全部音效程序化合成(`sfx.gd`),无音频文件 |
| [06 / 22 save](../22_save_advanced/) | 最佳时间存 `user://coin_dash.json` |
| [33 loading_flow](../33_loading_flow/) | 状态机:TITLE → PLAYING ⇄ PAUSED → WON/LOST |
| [04 signals_ui](../04_signals_ui/) | coin/hazard/goal 用信号通知 game 控制器 |

## 学到什么:把系统粘起来

### 1. 游戏状态机
```gdscript
enum State { TITLE, PLAYING, PAUSED, WON, LOST }
```
真实游戏的骨架不是某个炫技功能,而是**清晰的状态流**:标题→玩→(暂停)→赢/输→重开。每个状态决定:显示什么 UI、是否暂停、响应哪些输入。

### 2. 暂停的正确姿势(process_mode)
```
Main (process_mode = ALWAYS)      ← 控制器 + HUD:暂停时仍跑,能读输入解除暂停
└── World (process_mode = PAUSABLE) ← 游戏世界:get_tree().paused 时冻结
```
- `get_tree().paused = true` 冻结所有 PAUSABLE 节点(玩家、金币、粒子)
- Main 设 ALWAYS → `_unhandled_input` / `_process` 照常 → 能显示暂停菜单、监听 Esc 解除
- **关键**:把游戏对象归到一个 `World` 节点统一设 PAUSABLE,Main/HUD 设 ALWAYS

### 3. 信号解耦实体与控制器
```gdscript
# coin.gd:不知道游戏规则,只喊"我被吃了"
signal collected(coin)
# game.gd:订阅,处理计分/音效/粒子/胜利判定
for c in coins_node.get_children():
    c.collected.connect(_on_coin_collected)
```
金币、岩浆、终点都是"哑"实体,只发信号;**游戏逻辑集中在 game.gd**。加新金币只要拖进 Coins 节点,`_ready` 自动连接。

### 4. 代码构建 HUD + 菜单
HUD(分数/时间)和居中遮罩菜单全在 `_build_hud()` 里代码生成 —— 没有为每个状态画一套 UI 场景。一个 overlay,切状态时换文字。

### 5. 胜利条件组合
```gdscript
func _on_goal(body):
    if coins_left == 0: _win()
    else: _flash_hint("还差 %d 个金币!" % coins_left)
```
到终点 + 集齐金币 = 双条件。没集齐就提示,不直接过关。

### 6. 程序化音效即时反馈
`sfx.gd` 合成金币"叮"、跳跃"啾"、胜利琶音、失败下行音 —— 这些即时音效是"游戏感"的一半,且 0 资源文件。

## 改造练习(把它做成真游戏)

1. **多关卡**:把 `main.tscn` 复制成 level_1/2/3,game.gd 加关卡切换(配 demo 33 的异步加载)。
2. **相机跟随**:加 Camera2D 子节点到玩家,做更大的横版关卡。
3. **敌人**:放 demo 32 的行为树敌人巡逻,碰到 = 失败。
4. **可变高跳**:松开跳键时 `velocity.y *= 0.5`,按越久跳越高。
5. **金币连击**:短时间连吃加倍计分 + 升调音效。
6. **主菜单场景**:独立 title.tscn,选关 + 看最佳纪录 + 设置(音量,配 demo 09 的 Bus)。
7. **手柄支持**:InputMap 里给 move/jump 加 JoypadButton,移动端加屏幕按钮。
8. **导出**:用 demo 11 打 Android 包,真机玩。

## 易踩坑(整合阶段才会遇到)

- **process_mode 继承**:子节点默认 INHERIT,跟父节点走。Main 设 ALWAYS 后,如果玩家直接挂 Main 下且 INHERIT,就**不会被暂停**。所以游戏对象要归到 PAUSABLE 的 World 下。
- **暂停时输入**:`get_tree().paused` 后,PAUSABLE 节点的 `_input` 也停了。解除暂停的输入必须在 ALWAYS 节点里处理。
- **Area2D 在暂停时**:`body_entered` 不会在暂停时触发(物理停了),正常。
- **reload_current_scene 前先取消暂停**:否则新场景一进来就是暂停态。本 demo `restart` 里先 `paused=false`。
- **信号连接时机**:`_ready` 里遍历 coins 连接 —— 金币必须是 `.tscn` 实例且在场景里。运行时再生成的要单独连。
- **粒子在暂停时**:World 下的粒子暂停时不动,正常(拾取发生在 PLAYING)。
- 最佳时间用 `float` 存,`best < 0` 表示"还没纪录",别用 0(0 秒是合法成绩)。
