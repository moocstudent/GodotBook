# Demo 14 — AnimationTree (State Machine)

用代码构造完整的 **AnimationTree 状态机**:`idle ↔ walk → jump → idle`。整个状态机、3 个 Animation、所有 transition 都在 GDScript 里建,**0 编辑器拖拽**。

## 跑起来

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```

- A/D 移动 → idle ↔ walk 自动切
- Space → travel 到 jump,播完自动回
- 顶部 `state:` Label 实时显示当前状态机所在节点

## AnimationPlayer vs AnimationTree

| | AnimationPlayer | AnimationTree |
|---|---|---|
| 用途 | "播放一段动画" | "决定**当前**播哪段、怎么混合" |
| 资源 | 多个 Animation in library | 一棵节点树(状态机 / BlendTree / BlendSpace) |
| 角色实战 | 总有,但通常**被 AnimationTree 接管** | 推荐入口 —— 处理角色全部动画逻辑 |

AnimationTree 通过 `anim_player` 字段引用 AnimationPlayer,**自己不存动画**,只决定怎么播。

## 学到什么

### 1. 三种 root 节点(看 `tree_root` 怎么挑)
```
AnimationTree.tree_root = ?
├── AnimationNodeStateMachine   ← 状态机(本 demo)
├── AnimationNodeBlendTree      ← 子图,内部任意节点连线
├── AnimationNodeBlendSpace1D   ← 1D 混合(速度 → idle/walk/run 渐变)
└── AnimationNodeBlendSpace2D   ← 2D 混合(方向 + 速度,常用顶视角)
```
**状态机适合"切"**(idle 切 walk),**BlendSpace 适合"融"**(0→0.5→1 速度下平滑过渡)。
真实游戏:外层状态机 + 每个状态内部是个 BlendSpace。本 demo 不嵌套,体会基础。

### 2. 状态机节点关键 API
```gdscript
var sm := AnimationNodeStateMachine.new()
sm.add_node("idle", anim_node, Vector2(120, 100))    # 位置只是编辑器视觉
sm.set_start_node("idle")                            # 起点
sm.add_transition(from, to, transition)              # 连边
```

### 3. Transition 三种"启动方式"(switch_mode)
```gdscript
AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE  # 默认,条件满足立即切
AnimationNodeStateMachineTransition.SWITCH_MODE_SYNC       # 切到下个动画**保持同一时间点**(走→跑常用)
AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END     # 等当前动画播完再切(jump→idle 用这个)
```

### 4. Transition 三种"何时检查"(advance_mode)
```
ADVANCE_MODE_DISABLED   # 永不自动切(只能 travel 主动跳)
ADVANCE_MODE_ENABLED    # 默认,条件满足就切
ADVANCE_MODE_AUTO       # 不需要任何代码触发,只要条件 true 就切
```

### 5. 两种触发切换的方式

**方式 A — 条件式(适合连续状态)**
```gdscript
var t := AnimationNodeStateMachineTransition.new()
t.advance_condition = "is_walking"      # 引用一个 boolean 参数
sm.add_transition("idle", "walk", t)
```
然后在代码里:
```gdscript
anim_tree.set("parameters/conditions/is_walking", true)
```
**条件参数自动注册**到 `parameters/conditions/<name>`,无需提前声明。

**方式 B — 显式 travel(适合一次性事件)**
```gdscript
var pb: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")
pb.travel("jump")
```
- `travel()` 会**自动找最短路径**经过中间状态(必要时跨多边)
- `start()` 直接闪到目标,不经过 transition
- `current_node()` 读当前所在状态

### 6. `xfade_time` 交叉淡入
```gdscript
t.xfade_time = 0.15
```
状态切换的 150ms 内两个动画**混合播放**,看着平滑。0 = 硬切。

### 7. 参数路径
AnimationTree 的所有动态值都通过字符串路径读写:
```gdscript
anim_tree.set("parameters/conditions/is_walking", true)
anim_tree.get("parameters/playback")                    # 取 StateMachinePlayback 实例
anim_tree.set("parameters/Walk/blend_position", speed)  # BlendSpace1D 在子节点 Walk 下
```
**编辑器**右侧 Inspector 选中 AnimationTree 后,所有可读写参数都列出来 —— 不知道路径时直接抄。

## 关键代码片段

```gdscript
# 状态机骨架
var sm := AnimationNodeStateMachine.new()
sm.add_node("idle", _anim_node("idle"))
sm.add_node("walk", _anim_node("walk"))
sm.add_node("jump", _anim_node("jump"))
sm.set_start_node("idle")

# 双向条件
sm.add_transition("idle", "walk", _transition("is_walking"))
sm.add_transition("walk", "idle", _transition("is_idle"))

# jump 自动归 idle(等动画播完)
var t := AnimationNodeStateMachineTransition.new()
t.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
t.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
sm.add_transition("jump", "idle", t)

anim_tree.tree_root = sm
anim_tree.anim_player = anim_tree.get_path_to(anim_player)
anim_tree.active = true
```

## 改造练习

1. **加 run**:第四个状态,从 walk → run(条件 `is_fast`,按 Shift 时为 true)。
2. **idle → walk 用 BlendSpace1D 替代**:`walk` 节点改成 BlendSpace,blend_position = speed,内部 0/100/200 三档对应静止/慢走/快走。
3. **方向**:角色有左右朝向 → 一个布尔参数 `is_facing_left`,作为额外条件。
4. **可视化连线**:打开编辑器,选中 AnimationTree,Inspector → Tree Root,可以**图形化**编辑你代码建的同一棵树。状态机所见即所得。
5. **从代码保存为 .tres**:`ResourceSaver.save(sm, "res://player_anim.tres")`,之后 `tree_root = preload(...)` 不用每次 build。
6. **AnyState → 死亡**:加一个 `death` 状态;任意状态外加一条 transition 进入(advance_mode=AUTO + condition `is_dead`)。

## 易踩坑

- `anim_tree.active = false` 时**整个 tree 停止驱动 AnimationPlayer** —— 切场景时记得关,避免 phantom 动画。
- `parameters/conditions/<name>` 在 transition 引用前**就能 set**,后注册的 transition 会读到现值。
- 路径里漏了 `parameters/` 前缀(只写 `"conditions/is_walking"`) → set 静默无效,调试 30 分钟。
- `travel("jump")` 时如果 jump 不在 from-state 的可达图里,**默默忽略**,不报错。检查 transition 是否连通。
- `SWITCH_MODE_SYNC` 用错(jump→idle 用 SYNC)会让 idle 从动画中段开始播,看着"突然"。一次性动作用 AT_END。
- AnimationPlayer 的所有动画 NodePath 必须**相对 AnimPlayer**,不是相对 Player —— 本 demo 用 `"Body:scale"` 因为 AnimPlayer 和 Body 是兄弟节点同在 Player 下。
