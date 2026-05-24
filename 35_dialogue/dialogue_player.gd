extends RefCounted
class_name DialoguePlayer

# ╔══════════════════════════════════════════════════════════════╗
# ║  对话树驱动器(与 UI 解耦)。                                   ║
# ║                                                              ║
# ║  数据结构(dialogue.json):                                    ║
# ║   { start, nodes: { id: { speaker, text, choices:[ ... ] } } } ║
# ║  choice 可带:                                                ║
# ║    next         跳到哪个 node                                 ║
# ║    set          { flag: value } 设状态变量                    ║
# ║    require_gold  需要金币(不足则该选项灰掉)                  ║
# ╚══════════════════════════════════════════════════════════════╝

var data: Dictionary = {}
var current_id: String = ""
var state: Dictionary = {}        # blackboard:has_sword、quest_flags ...
var gold: int = 60

func load_from_file(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	data = JSON.parse_string(f.get_as_text())
	return typeof(data) == TYPE_DICTIONARY

func start() -> void:
	current_id = data.get("start", "")

func current_node() -> Dictionary:
	return data.get("nodes", {}).get(current_id, {})

func is_finished() -> bool:
	var node := current_node()
	return node.is_empty() or (node.get("choices", []) as Array).is_empty()

# 返回可见选项(过滤掉条件不满足的;也可以选择显示但禁用)
func available_choices() -> Array:
	var node := current_node()
	return node.get("choices", [])

func choice_enabled(choice: Dictionary) -> bool:
	if choice.has("require_gold") and gold < int(choice["require_gold"]):
		return false
	return true

func pick(index: int) -> void:
	var choices := available_choices()
	if index < 0 or index >= choices.size():
		return
	var choice: Dictionary = choices[index]
	if not choice_enabled(choice):
		return

	# 扣费
	if choice.has("require_gold"):
		gold -= int(choice["require_gold"])
	# 设状态
	if choice.has("set"):
		for k in choice["set"]:
			state[k] = choice["set"][k]

	current_id = choice.get("next", current_id)
