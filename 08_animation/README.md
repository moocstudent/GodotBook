# Demo 08 — Animation (Tween + AnimationPlayer)

并排展示 Godot 两种动画方式:**Tween**(代码即用,适合一次性反馈)和 **AnimationPlayer**(时间轴动画,适合复杂/循环)。

## 跑起来

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```

- **左边 Button**:点一下,Tween 触发一次"放大-回弹+变色"
- **中间方块**:点 "Play intro + idle" → 飞入 + 淡入,接着持续脉动(队列)
- **右边方块**:启动就在循环呼吸(AnimationPlayer 的 `idle_loop`)

## 学到什么

### 1. Tween vs AnimationPlayer 的选择

| 维度 | Tween | AnimationPlayer |
|------|-------|-----------------|
| 创建方式 | 代码 `create_tween()` | 资源 `.tres` / 编辑器时间轴 / 代码构造 |
| 一次性 vs 重用 | 一次性(可重复 `create_tween`) | 资源化,反复 `play()` |
| 复杂度 | 单/双属性的小动作 | 多对象多属性、关键帧、调用方法 |
| 编辑器可视化 | ✗ | ✓ 强大的时间轴 |
| 信号 | `finished` | `animation_finished(name)`,`animation_started` 等 |
| 何时用 | UI 按钮反馈、Tooltip 弹出、伤害弹字 | 角色动作、过场、复杂界面入场 |

经验法则:**3 行能写完 → Tween,30 帧关键帧 → AnimationPlayer**。

### 2. Tween 的语法
```gdscript
var t := create_tween()                          # 创建
t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)   # 默认缓动
t.tween_property(node, "scale", Vector2(1.3,1.3), 0.1)   # 串行
t.parallel().tween_property(node, "modulate", Color.RED, 0.1)  # 并行
t.tween_callback(my_func)                        # 调函数
t.tween_interval(0.5)                            # 等待
t.tween_property(...).from(Vector2.ZERO)         # 指定起点
```
**链式**,默认**串行**(一个接一个),用 `.parallel()` 让下一条与上一条同时。

`Tween.TRANS_*` 12 种曲线 + `EASE_IN/OUT/IN_OUT` —— 试试 `TRANS_ELASTIC` + `EASE_OUT`,糖度直接拉满。
[Tween 缓动曲线对照](https://docs.godotengine.org/en/stable/classes/class_tween.html)

### 3. 代码构造 AnimationPlayer
```gdscript
var anim := Animation.new()
anim.length = 1.6
anim.loop_mode = Animation.LOOP_LINEAR

var track := anim.add_track(Animation.TYPE_VALUE)
anim.track_set_path(track, "../AnimTarget:scale")   # NodePath:属性
anim.track_insert_key(track, 0.0, Vector2.ONE)
anim.track_insert_key(track, 0.8, Vector2(1.12, 0.92))
anim.track_insert_key(track, 1.6, Vector2.ONE)

var lib := AnimationLibrary.new()
lib.add_animation("idle_loop", anim)
anim_player.add_animation_library("", lib)
```
**实际工作中你 99% 在编辑器里拖**,但理解底层 API 让你:
- 程序化生成动画(过程动画、AI 生成)
- 调试别人项目的动画
- 在运行时给生成的对象挂动画

### 4. 轨道的 NodePath 写法
```
"../AnimTarget:scale"
 └────┬────┘ └─┬──┘
   节点路径    属性
```
- `..` = AnimationPlayer 的父节点,本 demo 即 Main
- `AnimTarget:scale` = 目标节点的 scale 属性
- 嵌套:`"player/sprite:modulate:a"` 改 sprite.modulate 的 alpha 分量

### 5. 播放队列
```gdscript
anim_player.play("intro")
anim_player.queue("pulse")     # intro 播完接 pulse
```
适合"入场动画 → 待机动画"这种链式。也可以监听 `animation_finished` 自己控制。

### 6. AnimationTree(未做,但要知道)
真正的角色动画(行走/跑/跳/攻击混合)用 **AnimationTree** 节点 + AnimationPlayer。AnimationTree 是状态机/混合树,AnimationPlayer 提供叶子动画。下一个层级的内容。

## 改造练习

1. **伤害飘字**:
   ```gdscript
   var label := Label.new(); label.text = "-25"
   add_child(label)
   var t := create_tween().set_parallel()
   t.tween_property(label, "position:y", label.position.y - 60, 0.6)
   t.tween_property(label, "modulate:a", 0.0, 0.6)
   t.chain().tween_callback(label.queue_free)
   ```
2. **shake**:相机/UI 抖动:`Tween` 加 `tween_method(_apply_shake, 0.0, 1.0, 0.3)`,函数里 set `offset = Vector2(randf_range(-8,8), randf_range(-8,8))`。
3. **method 轨道**:Animation 可以 `TYPE_METHOD`,在第 0.4s 调一个函数(比如生成粒子)。
4. **混合**:`anim_player.play("walk")` 然后 `play("attack", -1, 1.0, false)` 第二个参数是 blend time。
5. **存成 .tres**:在编辑器里录一段 Animation,Save → 资源文件,然后 `var anim = load("res://walk.tres")` 装进 AnimationLibrary。

## 易踩坑

- Tween 默认在节点被 `queue_free` 时也会被 kill;但**绑到 SceneTree 的 tween 不是**。一般用 `create_tween()`(节点级),除非真要全局。
- `tween_property` 的目标值类型必须与属性当前类型一致 —— `position` 是 `Vector2`,你传 `int` 会运行时报错。
- AnimationPlayer 的 NodePath **必须从 AnimationPlayer 的视角写**,不是从 Main。`../A:scale` 不是 `A:scale`。
- 修改了循环动画但视觉上没变?可能上一个 play 还在跑 —— `anim_player.stop()` 再 `play()`。
- Tween 不能像 jQuery 那样 `.stop()` 后继续 —— 一旦完成或 kill 就废,需要再 `create_tween()`。
