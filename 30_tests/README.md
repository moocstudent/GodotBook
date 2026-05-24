# Demo 30 — Tests (自包含测试框架)

一个 **~80 行的测试框架** + 示例测试套件 + headless CI 运行器。展示如何给 Godot 游戏写单元测试,以及怎么在 CI 里跑(退出码 0/1)。

## 跑起来

**GUI(看彩色结果):**
```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```
界面会跑所有测试,绿 PASS / 红 FAIL。**故意留了一个失败的测试** (`test_intentional_failure`) 演示报错格式。

**Headless(CI 用,有退出码):**
```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --headless --path . --script res://run_tests.gd
echo $LASTEXITCODE    # 0=全过, 1=有失败
```

## 文件结构

```
30_tests/
├── test_framework.gd     ← TestCase 基类(断言 + 运行器)
├── game_logic.gd         ← 被测代码(伤害/经验/堆叠/背包)
├── test_game_logic.gd    ← 测试套件(继承 TestCase)
├── run_tests.gd          ← headless 运行器(SceneTree 脚本)
├── main.gd / main.tscn   ← GUI 运行器
```

## 学到什么

### 1. 什么该测,什么不该测
| 好测(纯逻辑) | 难测(需要场景树/渲染) |
|---|---|
| 伤害公式 | 玩家移动手感 |
| 经验/等级曲线 | 粒子效果 |
| 物品堆叠 | shader 视觉 |
| 存档迁移(demo 22 的 migrate) | UI 布局 |
| 状态机转移规则 | 音频混音 |

**策略**:把核心规则抽成**纯函数 / 纯数据类**(本 demo 的 `GameLogic`),它们不依赖节点树,秒级可测。视觉/手感靠人工 + 录屏回归。

### 2. 测试框架的核心:断言 + 发现 + 汇总
```gdscript
extends TestCase

func test_damage_basic():           # test_ 开头 = 自动发现
    assert_eq(GameLogic.damage(50, 20), 30)
```
运行器用 `get_method_list()` 找所有 `test_*` 方法,逐个 `callv()` 跑,统计通过/失败。

### 3. before_each / after_each
```gdscript
var inv: GameLogic.Inventory

func before_each():
    inv = GameLogic.Inventory.new()   # 每个 test 前重置

func test_inventory_add():
    inv.add("potion", 3)   # 拿到的是干净的 inv
```
**测试隔离**:每个 test 用全新状态,互不污染。`test_inventory_isolation` 验证了这点。

### 4. 断言种类
```gdscript
assert_true(cond)            assert_false(cond)
assert_eq(a, b)              assert_ne(a, b)
assert_almost_eq(a, b, tol)  # 浮点比较
assert_null(v)               assert_not_null(v)
```
每个断言失败记录 `[测试名] 原因`,不中断后续(一个 test 里多个断言都会检查)。

### 5. Headless 运行器 = CI 的关键
```gdscript
extends SceneTree            # 不是 Node!直接当主循环

func _init():
    # ... 跑所有测试 ...
    quit(0 if all_passed else 1)    # 退出码给 CI
```
`--script res://run_tests.gd` 让 Godot **不开窗口、不进主场景**,直接跑这个脚本。`SceneTree._init()` 是入口。

CI(demo 19)里加一步:
```yaml
- name: Run tests
  run: godot --headless --path 30_tests --script res://run_tests.gd
```
退出码非 0 → CI 标红 → PR 不能合。

### 6. 退出码约定
- `0` = 全过
- `1` = 有失败
CI / shell 脚本据此判定。`echo $LASTEXITCODE`(PowerShell)/ `echo $?`(bash)看。

## 生产环境用 GUT

手搓框架够学原理。真实项目用 **[GUT (Godot Unit Test)](https://github.com/bitwes/Gut)**:
- 更丰富的断言(`assert_signal_emitted`, `assert_called`, mock/spy/stub)
- 场景树测试(`add_child_autofree`)
- 参数化测试、测试分组、超时
- 命令行 runner + CI 集成
- 编辑器内 GUI 面板

安装:Asset Library 搜 GUT,放 `addons/gut/`,启用。

GUT 写法几乎一样:
```gdscript
extends GutTest

func test_damage():
    assert_eq(GameLogic.damage(50, 20), 30)

func test_signal():
    watch_signals(obj)
    obj.do_thing()
    assert_signal_emitted(obj, "thing_done")
```
学了本 demo,GUT 5 分钟上手。

## 改造练习

1. **加 `assert_has` / `assert_in`**:测数组/字典包含。
2. **参数化测试**:一个 test 跑多组输入(伤害公式的边界值表)。
3. **测信号**:连接信号,记录是否触发、参数对不对。
4. **测 demo 22 的存档迁移**:`SaveSystem.migrate({version: 1})` → 断言升级到 v3 且字段齐全。这是回归测试的高价值场景。
5. **测异步**:`await` 一个 HTTPRequest mock,断言结果。
6. **覆盖率**:Godot 没内置覆盖率工具,但可以手动统计被测函数比例。
7. **接入 CI**:把测试步骤加进 demo 19 的 workflow,push 自动跑。

## 易踩坑

- **被测代码依赖节点树** → 单元测试难写。重构成纯函数(本 demo 的 `GameLogic` 全是 static / 纯类)。
- `run_tests.gd` 必须 `extends SceneTree`,入口是 `_init()` 不是 `_ready()`。
- headless 模式下**没有渲染**,任何创建 Sprite/visual 的测试会警告或失败。纯逻辑测试不受影响。
- `callv(method_name, [])` 调用动态方法名;参数不对会运行时报错。
- `get_method_list()` 也会返回基类(TestCase)的方法,所以**只筛 `test_` 前缀**。
- 浮点别用 `assert_eq`(`0.1+0.2 != 0.3`),用 `assert_almost_eq`。
- 故意失败的 `test_intentional_failure` 真用时删掉,否则 CI 永远红。
- GUT 和这个手搓框架不能混用(都定义 TestCase/GutTest 基类),选一个。
