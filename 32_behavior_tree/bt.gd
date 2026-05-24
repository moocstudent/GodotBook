extends RefCounted
class_name BT

# ╔══════════════════════════════════════════════════════════════╗
# ║  极简行为树框架(自包含,~120 行)                              ║
# ║                                                              ║
# ║  每个节点 tick() 返回三种状态之一:                            ║
# ║    SUCCESS / FAILURE / RUNNING                               ║
# ║                                                              ║
# ║  组合节点:                                                   ║
# ║    Sequence  — 全部 SUCCESS 才 SUCCESS(遇 FAILURE 即停;像 AND) ║
# ║    Selector  — 任一 SUCCESS 即 SUCCESS(遇 SUCCESS 即停;像 OR)  ║
# ║  叶子节点:                                                   ║
# ║    Condition — 检查,返回 SUCCESS/FAILURE                     ║
# ║    Action    — 干活,可返回 RUNNING(跨帧持续)                ║
# ╚══════════════════════════════════════════════════════════════╝

enum Status { SUCCESS, FAILURE, RUNNING }

# 基类
class Node extends RefCounted:
	var name: String = "node"
	func tick(_agent, _delta: float) -> int:
		return BT.Status.FAILURE
	# 返回当前正在 RUNNING 的叶子名(可视化用)
	func active_leaf() -> String:
		return name

# Sequence:依次 tick,任一失败则失败;全成功才成功
class Sequence extends Node:
	var children: Array = []
	var _running_idx := 0
	func _init(n: String, c: Array):
		name = n
		children = c
	func tick(agent, delta: float) -> int:
		for i in range(_running_idx, children.size()):
			var s: int = children[i].tick(agent, delta)
			if s == BT.Status.RUNNING:
				_running_idx = i
				return BT.Status.RUNNING
			if s == BT.Status.FAILURE:
				_running_idx = 0
				return BT.Status.FAILURE
		_running_idx = 0
		return BT.Status.SUCCESS
	func active_leaf() -> String:
		if _running_idx < children.size():
			return children[_running_idx].active_leaf()
		return name

# Selector:依次 tick,任一成功则成功;全失败才失败
class Selector extends Node:
	var children: Array = []
	var _running_idx := 0
	func _init(n: String, c: Array):
		name = n
		children = c
	func tick(agent, delta: float) -> int:
		for i in range(_running_idx, children.size()):
			var s: int = children[i].tick(agent, delta)
			if s == BT.Status.RUNNING:
				_running_idx = i
				return BT.Status.RUNNING
			if s == BT.Status.SUCCESS:
				_running_idx = 0
				return BT.Status.SUCCESS
		_running_idx = 0
		return BT.Status.FAILURE
	func active_leaf() -> String:
		if _running_idx < children.size():
			return children[_running_idx].active_leaf()
		return name

# Condition:用 Callable 返回 bool
class Condition extends Node:
	var fn: Callable
	func _init(n: String, f: Callable):
		name = n
		fn = f
	func tick(agent, _delta: float) -> int:
		return BT.Status.SUCCESS if fn.call(agent) else BT.Status.FAILURE

# Action:用 Callable 返回 Status(可 RUNNING)
class Action extends Node:
	var fn: Callable
	func _init(n: String, f: Callable):
		name = n
		fn = f
	func tick(agent, delta: float) -> int:
		return fn.call(agent, delta)
