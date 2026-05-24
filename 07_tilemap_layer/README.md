# Demo 07 — TileMapLayer (程序化)

按 **Space** 重新生成一段瓦片地形。整张图集 + 整个 TileSet 都是**运行时代码生成**的,**不依赖任何美术资源** —— 把 TileMap 的内核拆开给你看。

## 跑起来

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```

按 **Space** 不停刷新地形,**ESC** 退出。

## 学到什么

### 1. TileMap → TileMapLayer(Godot 4.3 的新写法)
Godot 4.2 之前用单个 `TileMap` 节点 + 内部多个 layer。
Godot 4.3 起拆成 **每层一个 `TileMapLayer` 节点**,层叠在父节点下:

```
World
├── Background (TileMapLayer)   ← 天空、远景
├── Terrain    (TileMapLayer)   ← 地面 (本 demo)
└── Decoration (TileMapLayer)   ← 草、花、矿
```
**优点**:每层是独立节点,可单独控制可见性、z_index、`modulate`、碰撞,甚至挂脚本。
**迁移**:旧 TileMap 项目打开会自动转换。

### 2. TileSet 三层结构
```
TileSet                            ← 资源,可保存为 .tres 复用
├── source 0:  TileSetAtlasSource  ← 一张图集
│   ├── texture = ImageTexture
│   ├── texture_region_size = (32, 32)
│   ├── tile (0, 0)
│   ├── tile (1, 0)
│   ├── tile (2, 0)
│   └── tile (3, 0)
└── source 1:  另一张图集 (可选)
```
- **TileSet** = "我这游戏里能用的所有瓦片字典"
- **AtlasSource** = "一张大图,切成网格,每格一种瓦片"
- 也可以用 `TileSetScenesCollectionSource`(每个瓦片是个场景),适合"瓦片就是个 Sprite + 脚本"的情形

### 3. 在代码里画图集
```gdscript
var img := Image.create(128, 32, false, Image.FORMAT_RGBA8)
img.fill_rect(Rect2i(0, 0, 32, 32), Color.GREEN)
...
var tex := ImageTexture.create_from_image(img)
```
- `Image` 是内存中的像素缓冲(类似 `Surface`)
- `ImageTexture.create_from_image(img)` 包成可被节点使用的 `Texture2D`
- 实战中你不会这么画,但理解"texture 只是个数据容器,从哪来都行"很关键

### 4. set_cell 三参数
```gdscript
terrain.set_cell(coords, source_id, atlas_coords)
```
- `coords`:格子在地图上的整数坐标 `Vector2i(x, y)`(注意是 i 后缀,整数向量)
- `source_id`:用哪个 source,本 demo 只有 0
- `atlas_coords`:在那张图集里取哪格 `Vector2i(0, 0)` / `Vector2i(1, 0)` ...

擦除一格:`set_cell(coords)`(后两个参数省略 = 清空)

### 5. 程序化生成的套路
本 demo 的高度图:
```gdscript
var ground_y := 6 + _rng.randi_range(-2, 2)   # 每列波动
for y in MAP_H:
    if y < ground_y: continue                  # 空气
    elif y == ground_y: t = Tile.GRASS         # 表层
    elif y < ground_y + 3: t = Tile.DIRT       # 土
    else: t = Tile.STONE                       # 石
```
这就是 Minecraft / Terraria 早期版本"地形发生器"最原始的形态。
进阶:把 `randi_range` 换成 `FastNoiseLite.get_noise_2d(x, 0)` —— 你就有了 1D 柏林噪声地形。

## 改造练习

1. **柏林噪声**:
   ```gdscript
   var noise := FastNoiseLite.new()
   noise.frequency = 0.08
   var h := int(8 + noise.get_noise_2d(x, 0) * 6)
   ```
   远比 randi_range 自然。
2. **加洞穴**:第二层 noise 当作密度图,密度 > 0 才放石头,否则空气。
3. **加碰撞**:`TileSetAtlasSource` 上加 `PhysicsLayer`,在每个 tile 的 `physics_layer_0/polygon_0` 加多边形 —— 玩家就能站在上面。需要先在 TileSet 里 `add_physics_layer()`。
4. **自动相邻**:把 4 种瓦片换成 `Terrains` 系统(TileSet 里配 terrain set),用 `set_cells_terrain_connect()`,瓦片会自动选边角图块。
5. **保存为 .tres**:在编辑器里把代码构造的 TileSet 拖到 FileSystem,生成 `tileset.tres`,以后就不用代码构造了。

## 易踩坑

- `set_cell` 第一参数必须是 `Vector2i`(整数);传 `Vector2`(浮点)会报错。
- 一个 TileMapLayer **只能绑一个 TileSet**;多个图集放进**同一个 TileSet 的不同 source**。
- 程序化造的 ImageTexture 在编辑器里看不到缩略图(没文件),运行起来是正常的。
- `terrain.clear()` 清空当前层。**别用 `terrain.queue_free()`**,那会删节点本身。
- Godot 4.3 之前 API 是 `set_cell(layer, coords, ...)`,有 layer 参数;TileMapLayer 拆完没了 —— 跟着教程时注意版本号。
