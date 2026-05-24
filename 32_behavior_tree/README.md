# Demo 32 — Behavior Tree (行为树 AI)

自包含的**行为树框架**(~120 行)+ 一个敌人 AI:巡逻 → 发现玩家追击 → 近身攻击 → 血量低逃跑。敌人颜色实时反映它当前在树的哪个节点。

## 跑起来

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```

- **WASD** 移动玩家(蓝点)
- 4 个敌人:**绿**=巡逻、**橙**=追击、**红**=攻击、**紫**=逃跑
- **K** 砍最近敌人 40 血 → 看它血量低于 30% 时切到逃跑

## 行为树 vs 状态机(demo 14)

| | State Machine (FSM) | Behavior Tree (BT) |
|---|---|---|
| 结构 | 状态 + 转移边 | 树:组合节点 + 叶子 |
| 扩展性 | 加状态 → 转移边爆炸(N²) | 加子树,局部修改 |
| 复用 | 难 | 子树可复制粘贴 |
| 适合 | 简单角色(idle/walk/jump) | 复杂 AI(敌人、NPC、Boss) |
| 调试 | 看当前状态 | 看当前 active 叶子路径 |

**经验**:动画用 FSM(demo 14),AI 决策用 BT。

## 学到什么

### 1. 三种返回状态
每个节点 `tick()` 返回:
```gdscript
enum Status { SUCCESS, FAILURE, RUNNING }
```
- **SUCCESS** — 这个节点做完了,成功
- **FAILURE** — 失败 / 条件不满足
- **RUNNING** — 还在进行中(跨多帧),下一帧继续从这里 tick

`RUNNING` 是 BT 的精髓 —— 让"走到某点""播放动画""等待 2 秒"这种**跨帧动作**自然表达。

### 2. 两种组合节点

**Sequence(序列,像 AND)**
```
依次 tick 子节点:
  遇到 FAILURE → 立即返回 FAILURE
  遇到 RUNNING → 返回 RUNNING(记住位置,下帧继续)
  全部 SUCCESS → 返回 SUCCESS
```
用于"**步骤**":condition 通过 **then** 执行 action。
```gdscript
BT.Sequence.new("attack", [
    BT.Condition.new("in_range?", _cond_attack_range),  # 先检查
    BT.Action.new("attack", _act_attack),               # 再攻击
])
```

**Selector(选择,像 OR)**
```
依次 tick 子节点:
  遇到 SUCCESS → 立即返回 SUCCESS
  遇到 RUNNING → 返回 RUNNING
  全部 FAILURE → 返回 FAILURE
```
用于"**优先级**":第一个能做的就做。
```gdscript
BT.Selector.new("root", [
    flee_sequence,    # 优先级最高:能逃就逃
    attack_sequence,  # 其次:能打就打
    chase_sequence,   # 再次:能追就追
    patrol_action,    # 兜底:都不行就巡逻
])
```

### 3. 叶子节点

**Condition** — 返回 bool 包装成 SUCCESS/FAILURE
```gdscript
BT.Condition.new("low_health?", func(agent): return agent.health < 30)
```

**Action** — 干活,返回 Status(可 RUNNING)
```gdscript
BT.Action.new("chase", func(agent, delta):
    agent.move_toward_player(delta)
    return BT.Status.RUNNING
)
```

### 4. 整棵树(本 demo 的敌人)
```
Selector "root"
├── Sequence "flee"      → 血<30%?  逃离
├── Sequence "attack"    → 近身?    攻击
├── Sequence "chase"     → 视野内?  追击
└── Action "patrol"      → (兜底)   随机游走
```
**每帧从 root 重新评估**:优先级天然有序。血量掉了 → flee 的 condition 变 true → 整个行为切换,**不需要写任何转移边**。这就是 BT 比 FSM 优雅的地方。

### 5. RUNNING 的位置记忆
```gdscript
class Sequence:
    var _running_idx := 0
    func tick(agent, delta):
        for i in range(_running_idx, children.size()):
            var s = children[i].tick(agent, delta)
            if s == RUNNING:
                _running_idx = i      # 记住卡在哪
                return RUNNING
            ...
        _running_idx = 0              # 完成后重置
```
让长动作不会每帧从头重判 condition(虽然本 demo 简单情况下也可以每帧重判)。

### 6. 可视化当前节点
```gdscript
func active_leaf() -> String:
    # Sequence/Selector 递归返回正在 RUNNING 的叶子
    return children[_running_idx].active_leaf()
```
本 demo 用敌人颜色 + label 显示 `active_leaf()` —— 调试 AI 的关键能力。

## 用 LimboAI 插件(生产推荐)

手搓 BT 适合学原理。**真实项目用 [LimboAI](https://github.com/limbonaut/limboai)**:
- 可视化编辑器(拖拽节点建树)
- 内置几十种节点(Cooldown、Repeat、Parallel、随机 Selector...)
- Blackboard(共享数据)
- HSM(分层状态机)+ BT 混合
- C++ 实现,快

安装:Godot Asset Library 搜 "LimboAI",或下载 GDExtension 版放 `addons/`。

LimboAI 的 BTTask 等价于本 demo 的 Node,概念完全一致,学了这个上手 LimboAI 5 分钟。

## 改造练习

1. **Inverter / Repeat 装饰节点**:`Inverter` 翻转子节点 SUCCESS↔FAILURE;`Repeat(n)` 重复 n 次。
2. **Parallel 节点**:同时 tick 所有子节点(边走边开火)。
3. **Blackboard**:加一个共享 Dictionary,Condition/Action 读写它(`last_seen_player_pos`),实现"记忆"。
4. **Cooldown 装饰**:包住 attack,强制 0.8s 间隔(本 demo 在 action 里手写了,抽象成节点更干净)。
5. **Wait 节点**:`return RUNNING` 直到累计 delta > t,然后 SUCCESS。
6. **群体协作**:敌人之间共享 blackboard,实现包抄(一个追、一个绕后)。
7. **接 demo 15 导航**:把 `_act_chase` 的直线移动换成 NavigationAgent2D 寻路,绕开障碍追。

## 易踩坑

- **每帧从 root tick**:本 demo 这样做(简单 AI 没问题)。复杂树要保留 RUNNING 状态避免重复判断高开销 condition。
- Sequence/Selector 的 RUNNING 语义初学易混:**Sequence 像 AND(遇错停),Selector 像 OR(遇对停)**。记这个就不乱。
- Condition 返回 RUNNING 是非法的(条件应该立即有答案)。只有 Action 可以 RUNNING。
- 叶子 Action 永远返回 RUNNING 且永不 SUCCESS → 它后面的兄弟节点永远轮不到。本 demo 的 chase 在到达攻击距离时返回 SUCCESS 让出控制。
- `Callable` 绑定 `self` 的方法:`_cond_low_health` 是 enemy 的方法,通过 `func(agent)` 签名传 agent。注意 Condition fn 签名 `(agent)`,Action fn 签名 `(agent, delta)`。
- 用 `set_script()` 动态附脚本时,节点的 `@onready` 在 `add_child` 后才解析 —— 本 demo 在 `setup()` 前先 `add_child`。
- 行为树**不存历史**(纯函数式每帧重算),要"记住"什么必须放 blackboard 或 agent 字段。
