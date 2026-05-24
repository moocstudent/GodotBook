extends RefCounted
class_name ObjectPool

# ╔══════════════════════════════════════════════════════════════╗
# ║  通用对象池                                                    ║
# ║                                                              ║
# ║  频繁 new/queue_free 节点会:                                  ║
# ║   - 触发 GC / 内存分配抖动                                     ║
# ║   - _ready/_enter_tree 开销                                   ║
# ║  对象池:预先造一批,复用(隐藏=回收,显示=取出),不真正销毁。 ║
# ╚══════════════════════════════════════════════════════════════╝

var _scene: PackedScene
var _parent: Node
var _free: Array[Node] = []        # 空闲(回收)列表
var _active: Array[Node] = []      # 使用中
var created_total := 0

func _init(scene: PackedScene, parent: Node, prewarm: int = 0) -> void:
	_scene = scene
	_parent = parent
	for i in prewarm:
		var n := _make()
		_recycle(n)

func _make() -> Node:
	var n := _scene.instantiate()
	_parent.add_child(n)
	created_total += 1
	return n

# 取一个(优先复用空闲的,没有才 new)
func acquire() -> Node:
	var n: Node
	if _free.is_empty():
		n = _make()
	else:
		n = _free.pop_back()
	n.set_process(true)
	if n.has_method("on_spawn"):
		n.on_spawn()
	_active.append(n)
	return n

# 归还(不销毁,只回收)
func release(n: Node) -> void:
	_active.erase(n)
	_recycle(n)

func _recycle(n: Node) -> void:
	n.set_process(false)
	if n is CanvasItem:
		n.visible = false
	_free.append(n)

func active_count() -> int:
	return _active.size()

func free_count() -> int:
	return _free.size()

func active_list() -> Array[Node]:
	return _active
