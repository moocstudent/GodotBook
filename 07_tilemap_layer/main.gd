extends Node2D

# 在代码里**完全程序化**地构造一个 TileSet,不需要外部图片资源:
#   - 用 Image.create / fill_rect 画 4 个 32x32 色块 -> 拼成 128x32 的图集
#   - 包成 ImageTexture
#   - TileSetAtlasSource 注册四个 cell (x=0..3, y=0)
#   - TileMapLayer 用 set_cell(coords, source_id, atlas_coords) 放格子
const TILE_SIZE := 32
const MAP_W := 30
const MAP_H := 16

# 4 种地形 -> atlas x 坐标
enum Tile {GRASS, DIRT, STONE, WATER}
const TILE_COLORS := {
	Tile.GRASS: Color(0.36, 0.58, 0.30),
	Tile.DIRT:  Color(0.55, 0.40, 0.25),
	Tile.STONE: Color(0.50, 0.50, 0.55),
	Tile.WATER: Color(0.20, 0.45, 0.75),
}

@onready var terrain: TileMapLayer = %Terrain
@onready var seed_label: Label = %SeedLabel

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	terrain.tile_set = _build_tile_set()
	_regenerate()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	elif event.is_action_pressed("regenerate"):
		_regenerate()

# —— 构造 TileSet ——————————————————————————————————————————

func _build_tile_set() -> TileSet:
	# 1) 画图集:128x32 横排,每格 32x32
	var img := Image.create(TILE_SIZE * 4, TILE_SIZE, false, Image.FORMAT_RGBA8)
	for t in TILE_COLORS.keys():
		var rect := Rect2i(t * TILE_SIZE, 0, TILE_SIZE, TILE_SIZE)
		img.fill_rect(rect, TILE_COLORS[t])
		# 描边,方便看出格子边界
		_draw_border(img, rect, Color(0, 0, 0, 0.35))
	var tex := ImageTexture.create_from_image(img)

	# 2) TileSet -> 加一个 atlas source
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	var source := TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	# 注册 4 个 cell (atlas 坐标)
	for x in 4:
		source.create_tile(Vector2i(x, 0))

	ts.add_source(source, 0)   # source_id = 0
	return ts

func _draw_border(img: Image, rect: Rect2i, color: Color) -> void:
	for x in range(rect.position.x, rect.position.x + rect.size.x):
		img.set_pixel(x, rect.position.y, color)
		img.set_pixel(x, rect.position.y + rect.size.y - 1, color)
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		img.set_pixel(rect.position.x, y, color)
		img.set_pixel(rect.position.x + rect.size.x - 1, y, color)

# —— 程序化地形 ————————————————————————————————————————

func _regenerate() -> void:
	var seed := Time.get_ticks_msec()
	_rng.seed = seed
	seed_label.text = "seed = %d  (Space 再来一张)" % seed

	terrain.clear()

	# 每列一个"高度",上面草、中间土、下面石头;偶尔挖个水洼
	for x in MAP_W:
		var ground_y := 6 + _rng.randi_range(-2, 2)
		for y in MAP_H:
			var t: int
			if y < ground_y:
				continue   # 空气
			elif y == ground_y:
				t = Tile.GRASS
			elif y < ground_y + 3:
				t = Tile.DIRT
			else:
				t = Tile.STONE
			# 10% 几率把表层换成水(凹地)
			if y == ground_y and _rng.randf() < 0.10:
				t = Tile.WATER
			# set_cell(coords, source_id, atlas_coords)
			terrain.set_cell(Vector2i(x, y), 0, Vector2i(t, 0))
