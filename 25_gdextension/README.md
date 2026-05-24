# Demo 25 — GDExtension (C++)

完整的 C++ GDExtension 模板:一个 `SineBobber` 自定义节点(让子节点正弦上下浮动),从源码到 .dll 到 Godot 编辑器里"出现在 Create Node 列表"的全流程。

## 文件清单

```
25_gdextension/
├── README.md
├── project.godot                      ← Godot 项目
├── main.tscn / main.gd                ← 演示场景(支持优雅降级)
├── godotstuff.gdextension             ← 给 Godot 看的"哪个 .dll 对应哪个平台"
├── SConstruct                         ← 编译脚本(SCons)
├── build.ps1                          ← Windows 一键编译
├── src/
│   ├── register_types.h / .cpp        ← 入口,把 SineBobber 注册到 ClassDB
│   ├── sine_bobber.h
│   └── sine_bobber.cpp                ← 实际功能
├── bin/                               ← 编译产物(.dll/.so/.dylib),build.ps1 生成
└── godot-cpp/                         ← C++ binding,build.ps1 自动 git clone
```

## 跑起来(两个阶段)

### 阶段 A:不编译也能开

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```
项目能打开,场景能跑,但 `SineBobber` 类没注册,会用 **Tween 模拟版**代替 —— 你看到 8 个方块上下浮动,只是不是 C++ 算的。屏幕顶部显示警告。

### 阶段 B:编译 C++ 部分

```powershell
& .\build.ps1
```
- 自动装 SCons(Python 包)
- 自动 git clone godot-cpp(4.3 分支)
- 编译 godot-cpp 自身(约 3 分钟,首次)
- 编译你的 extension(快,几秒)
- 输出到 `bin/libgodotstuff.windows.template_debug.x86_64.dll`

重启 Godot,**屏幕顶部从警告变成 "[OK] SineBobber 已加载"**。

## 前置条件

- **Python 3.8+** 在 PATH
- **Visual Studio 2022 + "Desktop development with C++"**(或 VS Build Tools,只装编译器,8GB)
- **git**

Linux:gcc + python + scons + git。
macOS:Xcode Command Line Tools + python + scons。

## 学到什么

### 1. GDExtension 是什么
"C++ 写的 Godot 节点"。**不是**改 Godot 源码再编译整个引擎(那叫"模块"/`modules/` 路线),而是:
- C++ 编出 **`.dll` / `.so` / `.dylib`**
- Godot 启动时加载这些 .dll
- 你的 C++ 类**注册到 ClassDB**,从此 GDScript 能 `var x = SineBobber.new()` 一样用

类比:
- Python 写的 **C 扩展**
- Node.js 写的 **native module**
- Unity 的 **native plugin**

### 2. 何时用 GDExtension,何时不用

| 用 | 不用 |
|---|---|
| 需要每帧 10000+ 次小计算(物理、AI、寻路) | 业务逻辑,UI 状态机 |
| 接 C 库(libcurl、SQLite、OpenCV) | 调 web API |
| 解析二进制格式(自定义存档、网络包) | JSON / CSV |
| 一个节点,大量实例 | 一两个独特对象 |

**先 GDScript,profile 找瓶颈,再 GDExtension 替换瓶颈**。99% 的游戏不需要它。

### 3. 三个必需文件

**A. `.gdextension`**(给 Godot 看)
告诉 Godot 哪个平台用哪个 .dll,以及入口函数名:
```ini
[configuration]
entry_symbol = "godotstuff_library_init"
compatibility_minimum = "4.3"

[libraries]
windows.debug.x86_64 = "res://bin/libgodotstuff.windows.template_debug.x86_64.dll"
linux.debug.x86_64   = "res://bin/libgodotstuff.linux.template_debug.x86_64.so"
...
```

**B. 入口 C 函数**(给 Godot 调)
```cpp
extern "C" GDExtensionBool GDE_EXPORT godotstuff_library_init(
    GDExtensionInterfaceGetProcAddress get_proc,
    const GDExtensionClassLibraryPtr library,
    GDExtensionInitialization *init
) {
    GDExtensionBinding::InitObject obj(get_proc, library, init);
    obj.register_initializer(initialize_godotstuff_module);
    obj.register_terminator(uninitialize_godotstuff_module);
    obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return obj.init();
}
```

**C. 你的 C++ 类**
```cpp
class SineBobber : public Node2D {
    GDCLASS(SineBobber, Node2D)         // 宏:让它被 Godot 识别

protected:
    static void _bind_methods() {       // 注册属性/方法/信号
        ClassDB::bind_method(...);
        ADD_PROPERTY(...);
    }

public:
    void _ready() override;             // Godot 自动调,对应 GDScript _ready
    void _process(double delta) override;
};
```

`GDCLASS` 宏展开后做了一堆元数据,让 Godot 知道继承关系、内存管理等。**漏写就编译不过**。

### 4. 暴露属性给 Inspector
```cpp
// 在 _bind_methods 里
ClassDB::bind_method(D_METHOD("set_amplitude", "v"), &SineBobber::set_amplitude);
ClassDB::bind_method(D_METHOD("get_amplitude"),     &SineBobber::get_amplitude);
ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "amplitude"),
             "set_amplitude", "get_amplitude");
```
Variant::FLOAT / INT / STRING / VECTOR2 / OBJECT 等,对应 Godot 内置类型。

属性出现在 Inspector + GDScript 可 `node.amplitude = 50` 直接读写。

### 5. SCons 构建链
```
godot-cpp/                ← 头文件 + 静态库(godot 提供的 binding)
    │
    │ 编译产物
    ▼
godot-cpp/bin/libgodot-cpp.windows.template_debug.x86_64.lib
    │
    │ 链接进
    ▼
你的源码 -> bin/libgodotstuff.windows.template_debug.x86_64.dll
```

SConstruct 关键:
```python
env = SConscript("godot-cpp/SConstruct")    # 继承所有平台 / 编译参数设置
env.Append(CPPPATH=["src/"])
sources = Glob("src/*.cpp")
env.SharedLibrary("bin/libgodotstuff{}{}".format(env["suffix"], env["SHLIBSUFFIX"]), sources)
```

### 6. target 三种
- `template_debug` —— **调试包**,有 assertion,体积大,慢。开发用
- `template_release` —— **发布包**,优化开满
- `editor` —— 给 Godot 编辑器用(罕见,只在做自定义工具节点时)

发版时**两份都要**(.gdextension 里两行都填),Godot 在 export 时自动选 release。

### 7. 跨平台编译

| 平台 | 命令 | 备注 |
|------|------|------|
| Windows x64 | `scons platform=windows target=template_debug` | VS 2022 |
| Linux x64 | `scons platform=linux target=template_debug` | gcc |
| macOS | `scons platform=macos target=template_debug` | Xcode CLT,自动 universal arm64+x86_64 |
| Android arm64 | `scons platform=android target=template_debug arch=arm64` | 装 Android NDK + ANDROID_NDK_ROOT |
| iOS | `scons platform=ios target=template_debug` | macOS only |
| Web | `scons platform=web target=template_debug` | emscripten |

要 CI 一次出全平台:GitHub Actions 多 job(参考 demo 19)。

### 8. 优雅降级模式
本 demo 在 `main.gd` 里:
```gdscript
if not ClassDB.class_exists("SineBobber"):
    # GDExtension 未编译 -> 用 Tween fallback
    _spawn_gdscript_fallback()
else:
    _spawn_cpp_bobbers()
```
**重要工程实践**:发布给团队成员时,不应该 "git clone 完打开就崩"。提供 fallback 让人能体验,再去编译。

## C++ vs GDScript 速度对比

`SineBobber._process` 大约只有 5 个 FP 运算 —— C++ 不会快 100 倍。
GDExtension 的优势在:
- 数千个节点同时跑(类型化数据,无 GDScript 解释器开销)
- 复杂算法(物理求解、A* on 大地图)
- 调用 C / C++ 第三方库

如果你的 C++ 节点 _process 也只是 5 个数学 → 写 GDScript 一样快(Godot 4 的 GDScript 加了 typed array 后差距已经很小)。

## 改造练习

1. **加信号**:`ADD_SIGNAL(MethodInfo("peak_hit", PropertyInfo(Variant::FLOAT, "value")));`,在 `_process` 里到达 amplitude 顶部时 `emit_signal("peak_hit", elapsed)`。GDScript 端 `.peak_hit.connect(...)` 一样接。
2. **加方法**:`reset()` 把 elapsed 归零,从 GDScript `node.reset()` 调用。
3. **从 Vector2 输入 + 输出**:`Vector2 calc(Vector2 in)` 演示复杂类型。
4. **替换 demo 13 的粒子**:写一个 `ParticleField` C++ 节点,5000 个粒子在 CPU 算,看比 GDScript CPUParticles 快多少。
5. **PCM 合成**:把 demo 09 的 `BeepFactory.sine_beep` 改成 C++,生成 1 秒 22050Hz PCM 比 GDScript 快 ~20×(纯 byte 数组操作)。
6. **wrap libcurl**:GDExtension 链一个 C 库,得到比 HTTPRequest 更强的 HTTP 客户端。
7. **GDExtension 的 Resource 自定义**:写个 `class MySaveData : public Resource`,Inspector 可视化、可 `ResourceSaver.save()`。

## 易踩坑

- **godot-cpp 的版本必须匹配 Godot 编辑器版本**:Godot 4.3 配 godot-cpp 4.3 分支。版本错位运行时 crash。
- 改了 C++ 重编后,**Godot 编辑器可能持有 .dll 句柄**,SCons 写入失败。先关 Godot 再 build。
- `GDCLASS(A, B)` 的 B 必须**也是**通过 GDCLASS 或继承 Godot 内置类。直接 `class A : public Object` 不行。
- 属性 `Variant::FLOAT` 对应 C++ 的 `double` 不是 `float`。混用会有 silent 精度损失。
- Inspector 拖属性时编辑器调你的 setter —— 如果 setter 里访问还没 ready 的成员就崩。本 demo 用了简单赋值规避。
- `_process` 在编辑器里也会被调用(因为 GDExtension 默认 `tool` 风格)→ 编辑器视图鬼畜。用 `Engine::get_singleton()->is_editor_hint()` 跳过。
- 编 Android 必须 `ANDROID_NDK_ROOT` 环境变量指向 NDK r23+。
- iOS 静态库链接顺序问题多,推荐用 cmake 而不是 scons(godot-cpp 也支持 cmake)。
- .gdextension 里**漏写平台行** → Godot 加载时找不到 .dll,SineBobber 不出现,**且不报错**。仔细检查每平台路径。

## 进阶资源

- [godot-cpp 仓库](https://github.com/godotengine/godot-cpp)
- [GDExtension 官方教程](https://docs.godotengine.org/en/stable/tutorials/scripting/gdextension/gdextension_cpp_example.html)
- godot-cpp/test/ 目录有完整可参考的例子
- 看 Godot 第三方插件(Box2D-Godot、godot-imgui)的源码,实战范本
