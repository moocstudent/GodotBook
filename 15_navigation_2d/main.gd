extends Node2D

@onready var nav_region: NavigationRegion2D = %NavRegion
@onready var obstacles_visual: Node2D = %ObstaclesVisual
@onready var path_drawer: Node2D = %PathDrawer
@onready var agent: Node2D = %Agent
@onready var nav_agent: NavigationAgent2D = %NavAgent
@onready var target_marker: Node2D = %TargetMarker
@onready var status: Label = %StatusLabel

@export var move_speed: float = 240.0

const SCREEN_W := 1152
const SCREEN_H := 648

# 几个障碍物矩形(本 demo 里用同一组数据:渲染 + 挖洞)
var _obstacles := [
	Rect2(280, 160, 220, 70),
	Rect2(640, 280, 180, 120),
	Rect2(360, 440, 280, 60),
	Rect2(820, 100, 60, 380),
]

var _start_pos: Vector2

func _ready() -> void:
	_start_pos = agent.position
	_build_navmesh()
	_draw_obstacles_visual()
	# NavigationAgent 自动用世界中"agent.position 所在的 nav region"

func _physics_process(delta: float) -> void:
	if nav_agent.is_navigation_finished():
		status.text = "到达目标 · 再点一处继续"
		return

	# get_next_path_position 返回路径上"下一个该走到的点"
	var next_pos: Vector2 = nav_agent.get_next_path_position()
	var dir := (next_pos - agent.global_position).normalized()
	agent.global_position += dir * move_speed * delta

	# 把当前路径用 path_drawer 重画
	queue_redraw_path()

	status.text = "走向 %s · 距离 %d · 路径点 %d" % [
		nav_agent.target_position.round(),
		int(agent.global_position.distance_to(nav_agent.target_position)),
		nav_agent.get_current_navigation_path().size(),
	]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_target(event.position)
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_R:
		agent.position = _start_pos
		nav_agent.target_position = _start_pos

func _set_target(world_pos: Vector2) -> void:
	# NavigationAgent2D 自带"把目标 clamp 到最近可达点"的能力
	nav_agent.target_position = world_pos
	target_marker.global_position = world_pos

# ── 程序化 navmesh:大外框 + 4 个障碍洞 ───────────────────────

func _build_navmesh() -> void:
	var np := NavigationPolygon.new()

	# 1) 外框:逆时针 = 实区(走得到的)
	var outer := PackedVector2Array([
		Vector2(20, 100),
		Vector2(SCREEN_W - 20, 100),
		Vector2(SCREEN_W - 20, SCREEN_H - 20),
		Vector2(20, SCREEN_H - 20),
	])
	np.add_outline(outer)

	# 2) 每个障碍 = 一圈 outline,挖空
	for r in _obstacles:
		np.add_outline(_rect_to_outline(r))

	# 3) 烘焙:从 outlines 生成实际的可行走多边形
	# Godot 4.3 推荐 API:
	NavigationServer2D.bake_from_source_geometry_data(
		np, NavigationMeshSourceGeometryData2D.new()
	)
	nav_region.navigation_polygon = np

func _rect_to_outline(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		r.position,
		r.position + Vector2(r.size.x, 0),
		r.position + r.size,
		r.position + Vector2(0, r.size.y),
	])

# ── 可视化障碍(渲染层,与 navmesh 数据同步)──────────────────

func _draw_obstacles_visual() -> void:
	for r in _obstacles:
		var rect := ColorRect.new()
		rect.position = r.position
		rect.size = r.size
		rect.color = Color(0.45, 0.45, 0.5, 1.0)
		obstacles_visual.add_child(rect)

# ── 路径可视化 ────────────────────────────────────────────────

func queue_redraw_path() -> void:
	path_drawer.queue_redraw()

func _on_path_drawer_draw() -> void:
	pass   # 占位,见 _draw

# Godot 不允许给子节点单独挂 _draw -> 让 Main 自己重写 _draw,
# 渲染到本节点(Node2D)上,等价效果
func _draw() -> void:
	var path: PackedVector2Array = nav_agent.get_current_navigation_path()
	if path.size() < 2:
		return
	# 黄色折线 + 节点圆圈
	for i in path.size() - 1:
		draw_line(path[i], path[i + 1], Color(1, 0.85, 0.3, 0.9), 3.0)
	for p in path:
		draw_circle(p, 4.0, Color(1, 0.85, 0.3, 1.0))

func _process(_delta: float) -> void:
	queue_redraw()        # Main 自己每帧重画路径
