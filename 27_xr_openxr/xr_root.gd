extends Node3D

# ╔══════════════════════════════════════════════════════════════╗
# ║  OpenXR 初始化 + 优雅降级                                       ║
# ║                                                              ║
# ║  有头显:初始化 OpenXR,启用立体渲染,XRCamera/XRController     ║
# ║          跟随真实头显和手柄。                                  ║
# ║  没头显:回退到桌面相机,你仍能看到场景(便于无设备开发)。      ║
# ╚══════════════════════════════════════════════════════════════╝

@onready var status: Label = %StatusLabel
@onready var desktop_cam: Camera3D = %DesktopCamera
@onready var grab_cube: MeshInstance3D = %GrabCube

var xr_interface: XRInterface
var xr_active := false

func _ready() -> void:
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		_enable_xr()
	elif xr_interface and xr_interface.initialize():
		_enable_xr()
	else:
		_fallback_desktop()

func _enable_xr() -> void:
	xr_active = true
	# 关键三步:
	get_viewport().use_xr = true                     # 1) viewport 走 XR 立体渲染
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)  # 2) 由头显合成器控制刷新
	desktop_cam.current = false                       # 3) 用 XRCamera 而非桌面相机

	status.text = ("[XR ON] OpenXR 已初始化。戴上头显,移动头/手柄即可。\n"
		+ "运行时:" + str(xr_interface.get_name()))

	# 监听手柄按钮(可选)
	for hand_name in ["LeftHand", "RightHand"]:
		var c := get_node("XROrigin3D/" + hand_name) as XRController3D
		c.button_pressed.connect(_on_button.bind(hand_name))

func _fallback_desktop() -> void:
	xr_active = false
	desktop_cam.current = true
	get_node("XROrigin3D/XRCamera3D").queue_free()  # 不用 XR 相机
	status.text = ("[XR OFF] 没检测到 OpenXR 运行时(没插头显 / 没装 SteamVR/Oculus)。\n"
		+ "已降级到桌面相机预览。场景结构与 VR 一致,看 README 配置头显。")

func _process(delta: float) -> void:
	# 让方块缓慢旋转,证明场景在跑
	grab_cube.rotate_y(delta)

func _on_button(button_name: String, hand: String) -> void:
	status.text = "[%s] pressed: %s" % [hand, button_name]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
