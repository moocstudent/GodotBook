# Demo 33 — Loading Flow (启动流程 + 异步加载)

完整启动流程:Splash logo 淡入 → 后台线程加载 game.tscn → 进度条 → 淡出切场景。**主线程不卡**,大场景加载时玩家看到流畅的进度条而不是黑屏冻结。

## 跑起来

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```

主场景是 `splash.tscn`(不是 main.tscn)。加载完会自动进 game.tscn,点按钮可回到 splash 重来。

## 学到什么

### 1. 同步 load 的问题
```gdscript
# ❌ 大场景这样加载,主线程冻结,窗口"无响应"
var scene = load("res://huge_level.tscn")
get_tree().change_scene_to_packed(scene)
```
`load()` 是**同步阻塞**:加载 50MB 场景要 2 秒,这 2 秒窗口完全冻死,Windows 弹"未响应"。

### 2. 后台线程加载(Godot 4 内置)
```gdscript
# 1) 发起请求(立即返回,加载在后台线程跑)
ResourceLoader.load_threaded_request("res://huge_level.tscn")

# 2) 每帧 poll 进度
var progress := []
var status := ResourceLoader.load_threaded_get_status(path, progress)
# progress[0] = 0.0 ~ 1.0
# status = IN_PROGRESS / LOADED / FAILED / INVALID_RESOURCE

# 3) 完成后取结果(此时是瞬间的,已经在内存里)
var scene := ResourceLoader.load_threaded_get(path)
```
主线程**只管轮询进度更新 UI**,实际 IO + 解析在 Godot 的后台线程,**界面始终流畅**。

### 3. 四种加载状态
```gdscript
ResourceLoader.THREAD_LOAD_IN_PROGRESS      # 加载中,读 progress[0]
ResourceLoader.THREAD_LOAD_LOADED           # 完成,可以 get
ResourceLoader.THREAD_LOAD_FAILED           # 加载出错(文件损坏等)
ResourceLoader.THREAD_LOAD_INVALID_RESOURCE # 路径无效
```

### 4. 最短展示时间(UX 细节)
```gdscript
const MIN_SPLASH_TIME := 1.5
...
if _load_done and _elapsed >= MIN_SPLASH_TIME:
    _go_to_game()
```
如果加载只要 0.2 秒,splash "一闪而过"很廉价。强制最短展示时间(1.5s)让品牌 logo 有存在感。**反过来**:加载要 10 秒也别只显示 logo,要有进度条让玩家知道没死机。

### 5. 切场景的两种 API
```gdscript
# A) 从文件(内部会同步 load,小场景用)
get_tree().change_scene_to_file("res://menu.tscn")

# B) 从已加载的 PackedScene(配合 threaded load,瞬间)
var scene := ResourceLoader.load_threaded_get(path)
get_tree().change_scene_to_packed(scene)
```
本 demo 用 B:splash 期间已经后台加载好,切换零延迟。

### 6. 淡入淡出转场
```gdscript
# 淡出当前
var t := create_tween()
t.tween_property(self, "modulate:a", 0.0, 0.4)
await t.finished
# 切场景
get_tree().change_scene_to_packed(scene)
```
`await tween.finished` 让代码等动画播完再切,顺滑。新场景在 `_ready` 里淡入。

### 7. 启动顺序(project.godot)
```ini
[application]
run/main_scene="res://splash.tscn"     # 第一个场景 = splash
```
真实游戏链:`splash → 主菜单 → (load) 游戏关卡`。还可以配 Godot 自带的 **boot splash**(纯图片,引擎启动时显示,在你的 splash.tscn 之前):`Project Settings → Application → Boot Splash`.

## 进阶:预加载多个资源

```gdscript
var paths := ["res://level.tscn", "res://music.ogg", "res://boss.tscn"]
for p in paths:
    ResourceLoader.load_threaded_request(p)

# poll 所有的平均进度
func total_progress() -> float:
    var sum := 0.0
    for p in paths:
        var arr := []
        ResourceLoader.load_threaded_get_status(p, arr)
        sum += arr[0] if arr.size() > 0 else 0.0
    return sum / paths.size()
```

## 改造练习

1. **多资源进度**:加载场景 + 音乐 + 大纹理,进度条显示总进度(见上)。
2. **加载提示轮播**:splash 底部每 2 秒换一句 "Tip: 按 Shift 冲刺"。
3. **Boot splash 配品牌图**:Project Settings → Boot Splash 设一张 logo PNG。
4. **失败重试**:`THREAD_LOAD_FAILED` 时显示重试按钮,重新 request。
5. **场景管理器单例**:做个 Autoload `SceneManager.change_scene(path)`,统一处理淡入淡出 + 后台加载,全游戏复用。
6. **保留加载的资源**:`change_scene_to_packed` 后 splash 被销毁,但已加载的 PackedScene 已转移给新场景树,不会重复加载。

## 易踩坑

- `load_threaded_get_status` 的 `progress` 参数是 **inout 数组**:传个 `[]` 进去,函数往里塞 `[0.0~1.0]`。别忘了取 `progress[0]`。
- 后台加载的资源**有依赖**(场景引用脚本/纹理)会一起加载,progress 反映总体。
- `change_scene_to_packed` 在**当前帧末尾**才真正换,不是立即。`await` 之后调是安全的。
- 同一个 path **重复 request** 会复用同一个加载任务,不会加载两遍。
- 后台线程加载**不能加载需要主线程的资源**(某些 GPU 资源),Godot 会自动在主线程补完最后一步,这就是为什么 `LOADED` 后 `get` 仍可能有微小延迟。
- splash 的 `MIN_SPLASH_TIME` 别设太长(>3s),玩家会嫌烦。移动端尤其。
- 如果 game.tscn 很小(本 demo 就很小),加载瞬间完成,你主要看到的是 MIN_SPLASH_TIME 在撑场。把 NEXT_SCENE 换成一个真的大场景才看得出后台加载的价值。
