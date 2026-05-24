# Demo 27 — XR / OpenXR (VR)

VR 脚手架:`XROrigin3D` + `XRCamera3D` + 双手 `XRController3D`,一个可抓的方块。**没头显也能跑**(自动降级到桌面相机预览),方便无设备时开发场景结构。

## 跑起来

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```

- 没插头显:看到桌面预览,顶部显示 `[XR OFF]`
- 插了头显且运行 SteamVR/Oculus:`[XR ON]`,戴上即进 VR

> XR 需要 **Forward+ 或 Mobile 渲染器**(Vulkan)。`gl_compatibility` 不支持立体渲染。本 demo 设了 `forward_plus`。

## 学到什么

### 1. OpenXR 是什么
**跨厂商 VR/AR 标准**(Khronos,跟 Vulkan 同家)。一套 API 适配:
- Meta Quest(独立 / Link)
- SteamVR(Index、Vive、WMR)
- Pico
- 大部分 PC VR

Godot 4 **内置 OpenXR**,不需要厂商 SDK。一份代码多头显跑。

### 2. 节点结构(VR 的标准骨架)
```
XROrigin3D                    ← 玩家在虚拟世界的"原点"(你移动它=瞬移/移动)
├── XRCamera3D                ← 跟随真实头显,自动立体渲染
├── XRController3D (left)     ← 跟随左手柄
│   └── 手柄模型 / 射线
└── XRController3D (right)    ← 跟随右手柄
```
- `XROrigin3D` = 房间地板中心。移动它 = 移动整个玩家
- `XRCamera3D` 的 transform **由头显驱动**,你不要手动设
- `XRController3D` 的 `tracker = &"left_hand" / &"right_hand"`

### 3. 三步启用 XR
```gdscript
var xr := XRServer.find_interface("OpenXR")
if xr and xr.initialize():
    get_viewport().use_xr = true                    # 立体渲染
    DisplayServer.window_set_vsync_mode(VSYNC_DISABLED)  # 头显合成器控刷新
    # XRCamera3D 自动接管
```

### 4. 优雅降级(本 demo 重点)
```gdscript
if xr and xr.initialize():
    _enable_xr()
else:
    _fallback_desktop()    # 没头显 -> 普通 Camera3D
```
**好处**:开发时不用每次都戴头显。改场景、写逻辑在桌面预览,真要测交互才戴。

### 5. 手柄输入
```gdscript
controller.button_pressed.connect(_on_button)        # 扳机/抓握/AB键
controller.input_float_changed.connect(_on_float)    # 扳机力度 0~1
controller.input_vector2_changed.connect(_on_stick)  # 摇杆

func _on_button(name):
    match name:
        "trigger_click": shoot()
        "grip_click": grab()
        "ax_button": menu()
```
OpenXR action 名是标准化的(`trigger`, `grip`, `primary`, `ax_button`...),在 **Project Settings → OpenXR → Action Map** 里配。

### 6. 抓取的基本思路
```gdscript
# 抓:把物体设为手柄的子节点(或每帧同步 transform)
func grab(obj):
    obj.reparent(controller)
# 放:reparent 回世界 + 给一个抛出速度
func release(obj):
    obj.reparent(world)
    obj.linear_velocity = controller_velocity
```
生产用 **godot-xr-tools** 插件(下面)有现成的 pickup/握把/移动组件。

## Quest 部署(Android 路线)

Quest 是 Android 设备,导出走 Android 流程(参考 demo 11)+ 额外配置:

1. **装 godot-xr-tools 或 OpenXR Vendors 插件**(提供 Quest loader)
   - Asset Library 搜 "Godot OpenXR Vendors"
2. **Android export 预设**:
   - XR Features → XR Mode = **OpenXR**
   - 勾 Meta / Khronos vendor 对应 plugin
3. **AndroidManifest**:插件自动加 VR 权限和 `<category android:name="com.oculus.intent.category.VR"/>`
4. **导出 APK → adb install → Quest 上的"未知来源"里启动**
5. **Quest Link 调试**:USB / Air Link 连 PC,Godot 直接 F5 跑到头显(走 SteamVR 或 Oculus runtime)

## PC VR 调试最快路径

1. 装 **SteamVR**(Steam 里搜)或 **Oculus 软件**
2. 插头显,确认 SteamVR 显示绿灯
3. Godot 里 F5 → 自动进 OpenXR runtime → 头显里看到场景

## godot-xr-tools(强烈推荐)

手搓 XR 交互很累。[godot-xr-tools](https://github.com/GodotVR/godot-xr-tools) 提供:
- 移动:瞬移、平滑移动、攀爬、攀爬
- 交互:pickup、按钮、拨杆、方向盘
- 手部:手部追踪、手指 IK
- UI:VR 里的 2D 面板交互(激光指针点按钮)

放 `addons/`,启用,拖组件即可。**几乎所有 Godot VR 游戏都用它**。

## 改造练习

1. **激光指针**:手柄前加 RayCast3D + 一条线,指向哪高亮哪。
2. **瞬移移动**:扳机按下时抛物线落点,松开瞬移 XROrigin3D 过去。
3. **抓取方块**:grip 按下时把 GrabCube reparent 到手柄,松开给抛出速度。
4. **手部追踪**:`XRHandModifier3D` + Quest 手部追踪,不用手柄。
5. **VR UI**:做个 `Viewport` 渲染 2D UI,贴到 3D quad 上,激光指针点击。
6. **passthrough(MR)**:Quest 透视,虚实结合,需要 OpenXR Vendors 的 passthrough 扩展。

## 易踩坑

- **gl_compatibility 不支持 XR** → `initialize()` 失败。必须 forward_plus / mobile。
- VR 必须**关 vsync**(`VSYNC_DISABLED`),由头显合成器以 72/90/120Hz 控刷新。开着会画面撕裂/卡。
- **晕动症**:平滑移动、相机加速度、低帧率都会让玩家吐。VR 必须稳定 72fps+,移动优先用瞬移。
- `XRCamera3D` 的 transform **别手动改** —— 它由头显驱动,改了下一帧被覆盖,且让玩家恶心。
- Quest 上 OpenXR 需要对应 vendor plugin,**纯 Godot 导出的 APK 在 Quest 上不会进 VR 模式**(只当普通 Android app)。
- 单位是**米**:玩家身高 1.6~1.8,桌子高 0.7~0.8。用真实尺寸,不然比例失真极晕。
- Action Map 没配 → 手柄按钮信号不触发。Project Settings → OpenXR → Action Map 检查。
- 调试输出在 Quest 上看不到 → 用 `adb logcat | findstr Godot`。
