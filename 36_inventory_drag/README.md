# Demo 36 — Inventory + Drag & Drop

24 格背包,物品可拖动:拖到空格 = 移动,拖到同物品 = 堆叠,拖到不同物品 = 交换。悬停显示 tooltip。展示 Godot **Control 内置拖放 API**(不用自己处理鼠标按下/移动/松开)。

## 跑起来

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```

拖动彩色方块到别的格子,试三种情况。底部 tooltip 显示悬停物品。

## 学到什么

### 1. Control 拖放三件套
Godot 内置拖放,你只需在 Control 上覆写三个虚函数:
```gdscript
# 1) 拖出:返回载荷数据 + 设预览。返回 null = 不可拖
func _get_drag_data(at_position) -> Variant:
    set_drag_preview(make_preview())
    return { "from": self, "item": item }

# 2) 悬停:这个数据能不能放到我这?返回 true 光标变"可放"
func _can_drop_data(at_position, data) -> bool:
    return data is Dictionary and data.has("item")

# 3) 松手:执行放置
func _drop_data(at_position, data) -> void:
    # 移动 / 堆叠 / 交换
```
**Godot 自动处理**:鼠标按下检测、拖动阈值、预览跟随、光标变化、松手分发。你只管"载荷是什么"和"怎么处理"。

### 2. 拖动预览
```gdscript
func _get_drag_data(pos):
    var preview := Panel.new()
    # ... 做一个跟随光标的小图 ...
    set_drag_preview(preview)
    return payload
```
预览是个临时 Control,跟着鼠标走,松手后自动销毁。可以做半透明、带数量角标。

### 3. 载荷(payload)= 任意数据
返回的 Variant 就是拖动载荷,`_can_drop_data` / `_drop_data` 收到的就是它:
```gdscript
return { "from": self, "item": item, "qty": qty }
```
带上 `from`(源 slot 引用)→ drop 时能清空源格、做交换。

### 4. 三种放置逻辑
```gdscript
func _drop_data(pos, data):
    var from = data["from"]
    if is_empty():
        set_item(data.item, data.qty); from.clear()        # 移动
    elif item == data.item:
        qty += data.qty; from.clear()                       # 堆叠
    else:
        # 交换:暂存我的,把对方放我这,我的给对方
        var t_item = item; var t_qty = qty
        set_item(data.item, data.qty)
        from.set_item(t_item, t_qty)
```

### 5. GridContainer 自动布局
```
[node name="Grid" type="GridContainer"]
columns = 6
```
子节点自动排成 6 列网格。加多少 slot 都自动换行。配 CenterContainer 居中。

### 6. mouse_filter(关键!)
slot 内的 Icon 和 Count 标签设 `mouse_filter = 2`(IGNORE):
```
[node name="Icon" type="ColorRect"]
mouse_filter = 2
```
否则鼠标事件被子节点吞掉,父 slot 的拖放和 `mouse_entered` 不触发。**这是拖放不工作的头号原因**。

### 7. tooltip
```gdscript
slot.mouse_entered.connect(_on_hover.bind(slot))
slot.mouse_exited.connect(func(): tooltip.text = "")
```
本 demo 用底部 Label 当 tooltip。Control 也有内置 `tooltip_text` 属性(鼠标悬停自动弹小框),但自定义 tooltip 更灵活(显示图标、稀有度颜色)。

## 改造练习

1. **拆分堆叠**:Shift+拖 拖一半数量(载荷里 `qty = floor(qty/2)`,源保留另一半)。
2. **右键快速用**:右键药水 → qty-1 + 触发效果。
3. **格子类型限制**:装备栏只接受 `type == "weapon"` 的物品(`_can_drop_data` 加判断)。
4. **拖到背包外丢弃**:在背包 Control 外覆写 `_drop_data` = 删除物品(确认弹窗)。
5. **拖到地面生成掉落物**:drop 到游戏世界 → 实例化一个可拾取的 Area2D(配 demo 05)。
6. **接存档**:把所有 slot 的 {item, qty} 序列化进 demo 22 存档。
7. **最大堆叠上限**:堆叠时调用 demo 30 的 `GameLogic.stack`,超出部分留在源格。

## 易踩坑

- **子节点没设 `mouse_filter = IGNORE`** → 拖放/hover 不触发(子节点截走了事件)。第一大坑。
- `_get_drag_data` 返回 null = 不可拖(空格子就该返回 null)。
- `set_drag_preview` 必须在 `_get_drag_data` 里调,且预览节点**不要**提前 add_child(Godot 自己管)。
- `_can_drop_data` 返回 false → 光标显示"禁止",`_drop_data` 不会被调。用它做类型/条件限制。
- drop 到自己身上(from == self)要特判,否则交换逻辑会把自己清空。
- 拖放是 Control 专属,Node2D 没有这套 API(2D 世界拖拽要自己处理 input)。
- 闭包绑定循环变量用 `.bind(slot)` 或 `var s := slot` 捕获当前值。
