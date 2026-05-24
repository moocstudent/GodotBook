extends Node2D

# player_color 通过 MultiplayerSynchronizer 同步给所有客户端
# 注:Color 同步要 set/get 转 string,这里我们用 PackedFloat32Array 表示 RGBA
@export var player_color: Color = Color.WHITE:
	set(v):
		player_color = v
		if is_inside_tree():
			$Body.color = v

@export var move_speed: float = 260.0

func _ready() -> void:
	# 节点 name 就是这个 peer 的 id(由 game.gd 在 spawn 时 set)
	$NameLabel.text = "peer " + name
	$Body.color = player_color

	# 只有"持有这个节点权威"的客户端能控制 -> set_process_input/physics
	var owner_id := name.to_int()
	# 设置 MultiplayerSynchronizer 的 authority(谁有权改它的同步属性)
	$Sync.set_multiplayer_authority(owner_id)

func _physics_process(delta: float) -> void:
	# 不是我的角色 -> 跳过(位置由 server 广播过来)
	if $Sync.get_multiplayer_authority() != multiplayer.get_unique_id():
		return

	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	position += dir * move_speed * delta
	position = position.clamp(Vector2(40, 40), Vector2(860, 560))
