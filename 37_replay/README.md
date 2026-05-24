# Demo 37 — Replay (确定性回放)

录制玩家输入,然后**确定性回放** —— 完美复现刚才的操作。关键:**录输入而非录位置**。配合固定步长,录像文件极小(只存每帧按了什么键)。

## 跑起来

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```

- **WASD** 移动,**空格** 留下橙色痕迹
- **1** 开始录制(世界重置)→ 操作一会儿 → **2** 停止
- **3** 回放(蓝点复位,绿痕迹重现你刚才的轨迹)
- **4** 存盘 → **5** 从盘读取并回放

## 学到什么

### 1. 录输入,不录状态
两种录像思路:
| | 录状态(每帧坐标) | 录输入(每帧按键) |
|---|---|---|
| 文件大小 | 大(每帧 N 个对象的 transform) | 极小(几个 bool + float) |
| 精度 | 完美但占空间 | 完美(若确定性) |
| 能否改规则后重算 | 否 | 能(同输入跑新逻辑) |
| 反作弊 | 难 | 服务器可重放验证 |

本 demo 录输入。一秒 60 帧,每帧 `{x, y, fire}` ≈ 20 字节,**一分钟录像才 70KB**。

### 2. 确定性的两个前提
```gdscript
# (1) 固定步长
Engine.physics_ticks_per_second = 60
func _physics_process(_delta):  # 永远是 1/60 秒
    _simulate(input)

# (2) 模拟是输入的纯函数
func _simulate(input):
    player.position += Vector2(input.x, input.y) * SPEED * (1.0/60.0)
    # 不读 randf()、不读 Time.now、不读未录的状态
```
**只要相同输入序列 → 相同结果**,回放就完美。

### 3. 破坏确定性的元凶
- `_process(delta)`:`delta` 每帧不同,帧率影响结果 → **必须用 `_physics_process` 固定步长**
- `randf()`:每次不同 → 用**带种子的随机**(`seed(12345)`),种子也存进录像
- `Time.get_ticks_msec()`:墙钟时间 → 改用 frame 计数
- 浮点跨平台差异:同一 CPU 没事,跨平台严格确定性要定点数(高级话题)

### 4. 回放 = 把录的输入喂回去
```gdscript
func _sample_or_replay_input():
    if mode == REPLAYING:
        return recording[replay_frame]   # 从录像取,不读键盘
    else:
        var input = {读真实键盘}
        if mode == RECORDING:
            recording.append(input)       # 录下来
        return input
```
**关键**:模拟代码 `_simulate` 完全不变 —— 它不知道输入是来自键盘还是录像。这就是"录输入"的优雅之处。

### 5. 录像文件格式
```json
{
  "version": 1,
  "physics_hz": 60,
  "start_pos": [576, 360],
  "frames": [
    {"x": 1.0, "y": 0.0, "fire": false},
    {"x": 1.0, "y": 0.0, "fire": true},
    ...
  ]
}
```
存初始状态 + 每帧输入。回放时从 start_pos 开始,逐帧喂 frames。

### 6. 应用场景
- **竞速 ghost**:回放最佳记录的半透明影子,玩家追自己
- **死亡回放**:roguelike "死亡时刻"慢镜头
- **联机对战录像**:RTS / 格斗游戏的录像分享(只传输入,几 KB)
- **反作弊**:服务器拿玩家输入重放,验证结果一致(分数没造假)
- **bug 复现**:崩溃时存最近 N 秒输入,开发者本地重放定位

## 改造练习

1. **带种子随机**:加敌人随机移动,`seed(replay_seed)`,种子存录像,回放时重置种子 → 敌人也完美复现。
2. **Ghost 模式**:回放时**同时**显示实时玩家 + 录像 ghost,竞速追逐。
3. **压缩录像**:相邻帧输入相同时只存"持续 N 帧",大幅缩小(游程编码)。
4. **2 倍速回放**:回放时一帧喂 2 个输入(或 `physics_ticks_per_second = 120`)。
5. **暂停 + 逐帧**:回放时空格暂停,方向键单帧步进(调试神器)。
6. **多对象**:录玩家 + 敌人 + 子弹的输入/生成事件,完整关卡回放。

## 易踩坑

- **用 `_process` 而非 `_physics_process`** → delta 抖动 → 回放和原始不一致。确定性的头号杀手。
- 模拟里调 `randf()` 不带种子 → 回放每次不同。随机必须可重现。
- 录像和模拟逻辑**版本要绑定**:改了 SPEED 常量后,老录像回放结果就变了。存 version,大改时拒绝旧录像。
- `recording.append(input)` 存的是 Dictionary 引用 —— 本 demo 每帧 new 一个新 dict 没问题;若复用同一个 dict 对象会全指向最后一帧。
- JSON 存 bool/float 没问题,但存 Vector2 要转数组(本 demo `start_pos` 存成 `[x, y]`)。
- 回放结束要切回 LIVE,否则卡在空输入。
- 真严格的跨平台确定性(联机)需要定点数学,浮点 SSE 指令在不同 CPU 可能差最后一位 —— 单机回放不用担心。
