# Demo 40 — Profiling (性能剖析 + 对象池)

自定义 profiler 叠加层(FPS / 帧时间 / 帧预算 / 节点数 / draw call / 显存)+ 对象池。按 **P** 在"对象池"和"new/queue_free"两种模式间切换,**实时对比**性能差异。

## 跑起来

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```

- **鼠标按住** 喷粒子,**+/-** 调喷射速率
- **P** 切换对象池 / new-free 模式
- 左上角 profiler:对比两种模式的 frame time 和 object count

## 学到什么

### 1. 自定义 profiler 叠加层
Godot 编辑器有内置 profiler(Debugger 面板),但**运行时叠加层**对发布版调优、移动端真机测试很有用:
```gdscript
extends CanvasLayer
func _process(delta):
    var ft = delta * 1000.0    # 帧时间(毫秒)
    label.text = "FPS: %d  frame: %.2f ms" % [Engine.get_frames_per_second(), ft]
```

### 2. Performance 单例(运行时性能数据)
```gdscript
Performance.get_monitor(Performance.OBJECT_COUNT)               # 对象总数
Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)      # 显存(字节)
Performance.get_monitor(Performance.MEMORY_STATIC)             # 静态内存
Performance.get_monitor(Performance.TIME_PROCESS)             # _process 总耗时
Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
get_tree().get_node_count()                                    # 场景树节点数
```
可以 `Performance.add_custom_monitor("game/enemies", callable)` 加自定义监控,出现在编辑器 Monitor 图表里。

### 3. 帧预算思维
- 60 FPS = 每帧 **16.67 ms**,30 FPS = 33.3 ms
- 你的所有逻辑 + 渲染必须塞进这个预算
- profiler 显示 `frame budget %`:超过 100% 就掉帧
- 分段计时找出谁吃了预算:
```gdscript
profiler.begin("ai")
update_all_enemies()
profiler.end("ai")        # 显示 [ai] 3.2 ms
```

### 4. 分段计时
```gdscript
func begin(name): _start[name] = Time.get_ticks_usec()
func end(name):   _sections[name] = Time.get_ticks_usec() - _start[name]
```
`Time.get_ticks_usec()` 微秒精度。把可疑代码块包起来,看它占多少帧时间。比瞎猜准。

### 5. 对象池(最常见的优化)
频繁 `instantiate()` + `queue_free()` 的代价:
- 内存分配 / 释放抖动
- 每个新节点跑 `_enter_tree` / `_ready`
- GC 压力

对象池:**预造一批,复用**。
```gdscript
func acquire():
    var n = _free.pop_back() if not _free.is_empty() else _make()
    n.set_process(true); n.visible = true
    n.on_spawn()           # 重置状态
    return n

func release(n):
    n.set_process(false); n.visible = false   # 不销毁,只隐藏回收
    _free.append(n)
```
切到对象池模式后看 `created` 数字:稳定后**不再增长**(全在复用),而 new-free 模式 object count 剧烈波动。

### 6. 对象池的关键:状态重置
```gdscript
func on_spawn():
    visible = true
    life = 0.0
    velocity = random_dir()      # 复用时必须重置所有状态!
```
**最大的坑**:复用的对象带着上次的状态。忘了重置 → 粒子从上次死亡位置冒出、血量没满等 bug。

### 7. 什么时候才需要对象池
- **高频生成/销毁**:子弹、粒子、伤害数字、敌人波
- 不是所有东西都池化(过度优化)。先 profile,确认 new/free 是瓶颈再做
- 现代 Godot 4 的对象创建已经不慢,池化主要省的是 `_ready` 开销 + 内存抖动

## 实测怎么看
1. new-free 模式,喷射速率拉到 400:看 object count 疯狂波动,frame time 抖
2. 按 P 切对象池:object count 稳定(`created` 停止增长),frame time 更平
3. 差异在低端设备 / 移动端更明显

## 性能优化清单(超出本 demo)
- **draw call**:合批(MultiMesh、TileMap、atlas),减少材质切换
- **物理**:减少碰撞体、用碰撞层过滤、别每帧 raycast
- **脚本**:`_process` 里别做重活;用 Timer / 信号驱动而非轮询
- **typed array**:`var a: Array[int]` 比 `Array` 快
- **避免每帧 new**:对象池、缓存
- **GPU**:compute shader(demo 26)卸载大规模计算

## 改造练习

1. **帧时间图**:画一条滚动的帧时间曲线(60 帧历史),超 16.6ms 红色。
2. **自定义 monitor**:`Performance.add_custom_monitor("game/particles", func(): return pool.active_count())`,出现在编辑器图表。
3. **池自动扩容/收缩**:空闲太多时真正释放一部分省内存。
4. **多池**:子弹池 + 敌人池 + 特效池,统一管理器。
5. **profile demo 13 粒子**:给 demo 13 加这个 profiler,对比 CPU vs GPU 粒子的 frame time。
6. **预算守卫**:每帧分配的时间用完就停止处理(分摊到多帧),保 60fps。

## 易踩坑

- 对象池**忘了重置状态** → 复用对象带旧数据。`on_spawn` 必须重置一切。
- 池化的对象 `queue_free` 了就脱离池 —— release 用隐藏 + set_process(false),**不要 free**。
- `set_process(false)` 停了 `_process` 但 `_physics_process` 要单独 `set_physics_process(false)`。
- profiler 自己也耗性能(每帧拼字符串)。发布版用快捷键开关,别常驻。
- `Performance.get_monitor` 返回的是上一帧的值,有一帧延迟,正常。
- frame time 用 `_process` 的 delta 测的是**渲染帧**;物理帧时间看 `TIME_PHYSICS_PROCESS` monitor。
- 别过早优化:先 profile 定位瓶颈,再针对性优化。对象池不是万能药。
