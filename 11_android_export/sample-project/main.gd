extends Control

@onready var info: Label = %DeviceInfo
@onready var tap: Button = %TapButton

var _taps: int = 0

func _ready() -> void:
	tap.pressed.connect(_on_tap)
	info.text = _describe()

func _describe() -> String:
	# OS.* 在 Android 上能跑通,导出包后看真机数据
	var lines := [
		"platform: %s" % OS.get_name(),
		"model:    %s" % OS.get_model_name(),
		"locale:   %s" % OS.get_locale(),
		"screen:   %s" % DisplayServer.window_get_size(),
		"version:  Godot %s" % Engine.get_version_info().string,
	]
	return "\n".join(lines)

func _on_tap() -> void:
	_taps += 1
	tap.text = "Tap me  (%d)" % _taps
