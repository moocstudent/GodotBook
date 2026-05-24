# Godot 学习仓 (godotstuff)

📖 **在线文档**: https://moocstudent.github.io/GodotBook/ ｜ 💻 **仓库**: https://github.com/moocstudent/GodotBook

按由浅入深的顺序组织的 **Godot 4** 学习 demo。每个 demo 都是一个**独立的 Godot 项目**(自带 `project.godot`),可单独打开运行。在线文档里每个 demo 一页:文档 + 全部源码(语法高亮),无需安装即可浏览。

## 学习路径

| # | 项目 | 知识点 | 关键节点 / API |
|---|------|--------|---------|
| 01 | [hello_world](01_hello_world/) | 节点树、`_ready()`、Label 文本绑定 | `Node2D`, `Label` |
| 02 | [sprite_movement](02_sprite_movement/) | `Input` 单例、`_process(delta)`、Vector2 速度 | `Sprite2D`, InputMap |
| 03 | [platformer_2d](03_platformer_2d/) | 物理体、重力、跳跃、土狼时间、跳跃缓冲 | `CharacterBody2D`, `move_and_slide()` |
| 04 | [signals_ui](04_signals_ui/) | Button 信号、自定义 signal、setter 链式更新 | `Button`, `VBoxContainer`, signal |
| 05 | [scene_instancing](05_scene_instancing/) | PackedScene 动态实例化、子弹工厂 | `Area2D`, `Timer`, `preload()` |
| 06 | [save_load_json](06_save_load_json/) | `FileAccess` 文件 IO、JSON 存档、版本迁移 | `user://`, `JSON.stringify` |
| 07 | [tilemap_layer](07_tilemap_layer/) | 代码构造 TileSet、TileMapLayer、程序化地形 | `TileMapLayer`, `TileSetAtlasSource` |
| 08 | [animation](08_animation/) | Tween 链式、AnimationPlayer、播放队列 | `Tween`, `AnimationPlayer`, `Animation` |
| 09 | [audio](09_audio/) | PCM 合成、Audio Bus、SFX 池 | `AudioStreamWAV`, `AudioServer` |
| 10 | [3d_basics](10_3d_basics/) | Camera3D、平行光、PBR 材质、轨道相机 | `Camera3D`, `MeshInstance3D`, `StandardMaterial3D` |
| 11 | [android_export](11_android_export/) | D 盘 SDK/JDK、debug keystore、CLI 打包、AAB | `setup-android-env.ps1` 一键脚本 |
| 12 | [shader](12_shader/) | CanvasItem shader、uniform、TIME、CRT/水波/glow/彩虹 | `.gdshader`, `ShaderMaterial` |
| 13 | [particles](13_particles/) | CPU vs GPU 粒子、Gradient 生命色带、爆炸+拖尾 | `CPUParticles2D`, `GPUParticles2D`, `ParticleProcessMaterial` |
| 14 | [animation_tree](14_animation_tree/) | 状态机、transition 条件、travel、xfade | `AnimationTree`, `AnimationNodeStateMachine` |
| 15 | [navigation_2d](15_navigation_2d/) | 程序化 navmesh、outline 挖洞、路径可视化 | `NavigationRegion2D`, `NavigationAgent2D` |
| 16 | [http_websocket](16_http_websocket/) | REST API 拉 JSON、WebSocket 双向通信、await 模式 | `HTTPRequest`, `WebSocketPeer` |
| 17 | [multiplayer](17_multiplayer/) | ENet host/client、Spawner、Synchronizer、权威模型 | `MultiplayerSpawner`, `MultiplayerSynchronizer` |
| 18 | [ios_export](18_ios_export/) | macOS+Xcode 工作流、签名、TestFlight、远程 Mac 方案 | 文档 + 字段 cheat sheet |
| 19 | [ci_github_actions](19_ci_github_actions/) | 多平台 matrix、artifact、itch.io butler、iOS workflow | 3 个 workflow yml |
| 20 | [3d_postfx](20_3d_postfx/) | Fresnel 菲涅尔边缘、SCREEN_TEXTURE 后处理、tonemap、多 CanvasLayer | `WorldEnvironment`, spatial shader |
| 21 | [3d_character_fps](21_3d_character_fps/) | FP 相机 yaw/pitch、鼠标 capture、CSG 关卡 | `CharacterBody3D`, `CSGCombiner3D` |
| 22 | [save_advanced](22_save_advanced/) | 多 slot、AES-256 加密、迁移链、云同步 PUT/GET | `FileAccess.open_encrypted_with_pass` |
| 23 | [editor_plugin](23_editor_plugin/) | `@tool`、EditorPlugin、Dock、Tools 菜单、Scene Stats | `addons/`, `plugin.cfg` |
| 24 | [localization](24_localization/) | CSV 程序化加载、tr() + format()、4 语种实时切换 | `TranslationServer`, `Translation` |
| 25 | [gdextension](25_gdextension/) | C++ 自定义节点、SCons、godot-cpp、跨平台 .dll | `GDCLASS`, `_bind_methods` |
| 26 | [compute_shader](26_compute_shader/) | RenderingDevice GPGPU、SSBO、boids 群体、GPU vs CPU | `RenderingDevice`, `.glsl #[compute]` |
| 27 | [xr_openxr](27_xr_openxr/) | OpenXR VR、XROrigin/XRCamera/XRController、Quest、降级 | `XRInterface`, `godot-xr-tools` |
| 28 | [steam_integration](28_steam_integration/) | GodotSteam、成就/排行榜/云存档、wrapper 降级 | `Engine.get_singleton("Steam")` |
| 29 | [discord_iap](29_discord_iap/) | Discord 富存在、Google/Apple 内购、抽象层 | `IAPService`, `DiscordPresence` |
| 30 | [tests](30_tests/) | 自包含测试框架、断言、headless CI runner、退出码 | `extends SceneTree`, GUT 对照 |
| 31 | [procedural_mesh](31_procedural_mesh/) | SurfaceTool/ArrayMesh、噪声星球、地形、法线 | `SurfaceTool`, `ArrayMesh`, `FastNoiseLite` |
| 32 | [behavior_tree](32_behavior_tree/) | 行为树框架、Sequence/Selector、RUNNING、敌人 AI | 自建 BT, `LimboAI` 对照 |
| 33 | [loading_flow](33_loading_flow/) | splash、后台线程加载、进度条、淡入淡出切场景 | `ResourceLoader.load_threaded_*` |
| 34 | [fluid_sph](34_fluid_sph/) | CPU 2D SPH 流体、密度/压力/粘性、空间哈希加速 | 自建 SPH, `FastNoiseLite` |
| 35 | [dialogue](35_dialogue/) | JSON 对话树、打字机、分支选项、条件跳转、状态 | 数据驱动, Dialogic 对照 |
| 36 | [inventory_drag](36_inventory_drag/) | 格子背包、Control 拖放、移动/堆叠/交换、tooltip | `_get_drag_data` 三件套 |
| 37 | [replay](37_replay/) | 确定性回放、录输入而非状态、固定步长、存读盘 | `_physics_process`, 种子随机 |
| 38 | [steam_p2p](38_steam_p2p/) | SteamMultiplayerPeer 大厅 P2P、传输无关、降级 ENet | `MultiplayerAPI` 换底层 peer |
| 39 | [mod_support](39_mod_support/) | 运行时挂 .pck/.zip、数据合并覆盖、mod 安全 | `load_resource_pack` |
| 40 | [profiling](40_profiling/) | 自定义 profiler 叠加、对象池、帧预算、Performance | `Performance`, 对象池 |
| 41 | [coin_dash](41_coin_dash/) | **毕业作**:完整平台小游戏,整合 03/05/09/13/22/33 | 状态机, process_mode, 信号 |

## 设计原则

每个 demo 满足:

1. **文件最小**:只用必要节点,不夹带模板代码。
2. **可读的 `.tscn`**:场景文件是文本,直接可 diff、可 AI 编辑。
3. **README 必备**:讲清"做什么 / 怎么跑 / 学了什么 / 下一步改造点"。
4. **GDScript 注释到位**:核心 API 第一次出现时注释含义。

## 环境要求

- **Godot 4.3+**(`Standard` 版即可,不需要 .NET 版)
- 安装路径:见 [INSTALL.md](INSTALL.md)
- 平台:Windows / macOS / Linux 都可
- 目标导出:Android / iOS(后续会在独立 demo 里加导出说明)

## 怎么打开一个 demo

**方式 A — 用编辑器:**
1. 启动 Godot → "Import" → 选中某个子目录里的 `project.godot`
2. 按 F5 运行

**方式 B — 命令行(最适合 AI/CI):**
```powershell
# 在某个 demo 目录里
& "D:\Godot\Godot_v4.x-stable_win64.exe" --path . 
# 直接运行主场景:
& "D:\Godot\Godot_v4.x-stable_win64.exe" --path . res://main.tscn
# Headless 跑脚本(单元测试常用):
& "D:\Godot\Godot_v4.x-stable_win64.exe" --headless --path . --script res://test.gd
```

## 文件结构约定

```
NN_demo_name/
├── project.godot       # Godot 项目配置(文本,可读)
├── main.tscn           # 主场景(文本,可读)
├── main.gd             # 主脚本
├── icon.svg            # 项目图标(占位)
├── README.md           # 本 demo 说明
└── (可选) assets/...   # 美术/音效资源
```

## GDScript 心智模型(给来自其他语言的人)

- **节点 = 对象**,场景 = 节点树。脚本附在节点上,扩展节点行为。
- `_ready()`:节点进入场景树后调用一次(类似 React `componentDidMount`)。
- `_process(delta)`:每帧调用,`delta` 是秒数(类似游戏循环 tick)。
- `_physics_process(delta)`:每物理 tick 调用,固定步长,处理移动/碰撞用这个。
- **信号 (signal)**:发布订阅,类似 Qt signal/slot 或 EventEmitter。
- `$NodeName` 或 `%UniqueName`:获取子节点的快捷语法。
- `@export var`:在编辑器面板上暴露字段(类似 Unity `[SerializeField]`)。
- `preload("res://...")` vs `load(...)`:前者编译期、后者运行时。

## 与其他游戏栈的对照

| 概念 | Godot | Unity | Unreal |
|------|-------|-------|--------|
| 主对象 | Node | GameObject | Actor |
| 行为脚本 | GDScript | MonoBehaviour | UCLASS |
| 场景文件 | `.tscn`(文本) | `.unity`(YAML/二进制) | `.umap`(二进制) |
| 资源引用 | `res://` | `Resources.Load` / Addressables | `/Game/` |
| 物理体 | `CharacterBody2D/3D` | `Rigidbody`/`CharacterController` | `Character`/`Pawn` |

## 文档站(GitHub Pages)

`build_site.ps1` 把所有 demo 渲染成静态 HTML 站(每个 demo 一页,文档 + 源码 tab,加总目录 `index.html`)。详见 [SITE.md](SITE.md)。

```powershell
& .\build_site.ps1     # 重新生成全站
```

## 下一步可以加的 demo(占位)

- 42 — 多关卡 + 关卡选择(给 41 加 level_1/2/3 + 进度存档)
- 43 — 主菜单 / 设置场景(音量 Bus、键位重绑、分辨率)
- 44 — 流体进 GPU(把 34 搬到 26 的 compute 框架)
- 45 — 对话接 i18n(35 + 24:多语言分支剧情)
- 46 — Roguelike 程序化关卡生成(BSP / 元胞自动机)
- 47 — 状态同步网游小游戏(17 + 41:联机版 Coin Dash)
- 48 — Shader 图鉴:20+ 常用 2D/3D shader 速查
