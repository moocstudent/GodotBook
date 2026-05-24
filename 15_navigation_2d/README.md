# Demo 15 — Navigation 2D (寻路)

点哪儿走哪儿,**自动绕开障碍**。Navmesh 完全在代码里 baked,黄色折线实时显示当前路径。

## 跑起来

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```

- 左键点空白处:绿色 Agent 走过去
- 点障碍物里:NavigationAgent 自动把目标 clamp 到最近可达点
- **R**:回到起点

## Godot 寻路三件套

```
NavigationRegion2D       ← 节点。容器,持有一个 NavigationPolygon 资源
├── navigation_polygon = NavigationPolygon.new()
│   ├── outlines    (Array[PackedVector2Array])   ← 输入:你画的可达/不可达边界
│   └── vertices/polygons                          ← 烘焙后:三角化后的实际可行走面

NavigationAgent2D        ← 节点。挂在"要寻路的角色"下
├── target_position
├── get_next_path_position()
└── is_navigation_finished()

NavigationServer2D       ← 全局单例。Godot 内部跑 A* 的就是它
└── bake_from_source_geometry_data(...)            ← 烘焙
```

## 学到什么

### 1. NavigationPolygon 的 outline 规则
- **第一条 outline = 可行走区域的边界**(凸/凹都可)
- **后续 outline = 洞**(障碍物),会从可行走区域里挖掉
- Outline 顶点顺序:Godot 内部会自动处理方向,你**别让线段自相交**就行

```gdscript
np.add_outline(PackedVector2Array([
    Vector2(20, 100),
    Vector2(SCREEN_W - 20, 100),
    Vector2(SCREEN_W - 20, SCREEN_H - 20),
    Vector2(20, SCREEN_H - 20),
]))                              # 外框
np.add_outline(obstacle_points)  # 挖洞 1
np.add_outline(obstacle_points)  # 挖洞 2
```

### 2. 烘焙(Bake)= 把 outlines 切成三角形
```gdscript
NavigationServer2D.bake_from_source_geometry_data(
    np, NavigationMeshSourceGeometryData2D.new()
)
```
**烘焙 = 一次性的 CPU 计算**,把声明式 outlines 变成实际可用的多边形数据。**编辑器里你点 "Bake NavigationPolygon" 那个按钮做的就是这事**。

烘焙完毕,`navigation_region.navigation_polygon = np` 让节点接管。

### 3. NavigationAgent2D 的工作流
```gdscript
# (1) 设目标
nav_agent.target_position = mouse_pos       # 自动 clamp 到最近可达点

# (2) 每物理帧,问"下一步去哪"
var next := nav_agent.get_next_path_position()
agent.global_position += (next - agent.global_position).normalized() * speed * delta

# (3) 判定到达
if nav_agent.is_navigation_finished():
    # 停下
```

Agent **自动**:
- 在 `target_position` set 时重新计算路径
- 你移动它时 next_position 自动指向当前 waypoint
- 距离 `path_desired_distance` 内时切到下一个 waypoint

### 4. 关键参数
| 参数 | 意义 | 默认 |
|------|------|------|
| `path_desired_distance` | 离 waypoint 多近算"到了这个 waypoint" | 1.0 |
| `target_desired_distance` | 离 target 多近算"到了终点" | 1.0 |
| `radius` | Agent 体积半径(避障用) | 10 |
| `max_speed` | 内部限速(用 `velocity_computed` 时用) | 100 |
| `avoidance_enabled` | 多 Agent 互相避让(RVO) | false |
| `debug_enabled` | 编辑器里可视化路径 | false |

本 demo 设 `path_desired_distance = 8`,绿方块不会卡 waypoint 抖动。

### 5. 拿到完整路径(可视化)
```gdscript
var path: PackedVector2Array = nav_agent.get_current_navigation_path()
for i in path.size() - 1:
    draw_line(path[i], path[i + 1], Color.YELLOW, 3.0)
```
本 demo 在 `Main._draw()` 里这么干,每帧重画。

### 6. NavigationObstacle2D vs 在 navmesh 上挖洞
两种处理障碍的方式:

**A. 烘焙时挖洞(本 demo)**
- 障碍位置**固定**,烘焙一次就完事
- 路径"硬走"绕开,效率高

**B. NavigationObstacle2D 节点(动态)**
- 障碍**会动**(载具、其他 Agent)
- Agent 用 `avoidance_enabled = true` 实时 RVO 避让
- 路径不变,但**速度被实时修正**

实战里两者**都要**:静态环境用 A,动态对象用 B。

### 7. 边界 / 走错的判定
`target_position` 设到不可达点(障碍里、navmesh 外),NavigationAgent 自动:
- 找最近的 navmesh 上的点
- 走到那儿,然后判定 `is_navigation_finished()`

如果 `target_position` 设的根本就不可能到达(navmesh 完全不连通),agent 走到最近点就停了。`is_target_reachable()` 可以提前判断。

## 改造练习

1. **多个 Agent**:加几个绿色方块,各自有 NavigationAgent2D,点鼠标后他们一起出发。开 `avoidance_enabled = true` 看互相避让。
2. **拖动障碍**:把 `_obstacles` 改成可拖动的,每次 drop 重新 `bake_from_source_geometry_data` —— 实时重建 navmesh(注意:每帧 bake 性能差,加 50ms throttle)。
3. **加入 TileMap**:用 demo 07 的 TileMapLayer,在 TileSet 里给 tile 加 `navigation_layer`,Godot 自动从 tile 形状生成 navmesh。
4. **3D**:换 NavigationAgent3D + NavigationRegion3D + NavigationMesh,API 一致,坐标换 Vector3。
5. **A* 直接调用**:跳过 NavigationAgent,直接 `NavigationServer2D.map_get_path(map_rid, from, to, true)`,得到原始路径数组。

## 易踩坑

- **烘焙没做**:`add_outline` 后忘记 bake → navmesh 是空的,Agent 永远 finished。
- **顶点顺序**:首条 outline 顺时针 vs 逆时针 Godot 自己识别,但**两条 outline 互相相交**会产生未定义行为,bake 出怪图。
- Agent **不在 navmesh 上**:Agent 的当前位置必须在某条 navmesh 内,否则 `get_next_path_position()` 给的方向乱。把起点放在白色区域内。
- `target_position` 不变时 **path 不会自动重算**。环境改了(挖洞 / 加洞 / 重 bake),要重新 `nav_agent.target_position = nav_agent.target_position` 触发一次。
- 物理移动写在 `_process` 而非 `_physics_process`,在不同帧率下表现不一致。本 demo 用 `_physics_process` 是对的。
- Godot 4.3 之前 API 有 `make_polygons_from_outlines()`,4.3 改成 `NavigationServer2D.bake_*`。教程要看版本号。
