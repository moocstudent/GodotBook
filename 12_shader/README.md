# Demo 12 — Shader (Canvas)

4 个独立 shader 同屏跑,**不依赖任何贴图**:CRT 扫描线、水面波纹、脉冲发光、滚动彩虹。1-4 数字键改 Glow 的脉冲速度,验证 uniform 实时变化。

## 跑起来

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```

## Shader 在 Godot 中的两种用法

### Visual Shader vs Code Shader
- **VisualShader**(可视化节点):拖连线,适合美术,生成代码可读
- **Code Shader**(本 demo):写 `.gdshader` 文本文件,语法是 **GLSL 的方言** + Godot 内置变量

实战中大部分人写文本,VisualShader 用作起点或学习。

### shader_type 三种
```glsl
shader_type canvas_item;  // 2D / UI(本 demo 全是这种)
shader_type spatial;      // 3D 物体表面
shader_type particles;    // 粒子计算
```

## 学到什么

### 1. 最小 canvas_item shader
```glsl
shader_type canvas_item;
void fragment() {
    COLOR.rgb *= vec3(1.0, 0.5, 0.5);
}
```
- `fragment()` 每个像素调一次
- 内置变量:
  - `UV` (vec2):当前像素的归一化坐标 (0,0)~(1,1)
  - `COLOR` (vec4):输入颜色(节点的 modulate × 贴图采样),你可以**读写**
  - `TIME` (float):自启动以来的秒数
  - `SCREEN_UV` (vec2):屏幕坐标
  - `TEXTURE` (sampler2D):节点的纹理(ColorRect 没纹理,Sprite2D 有)

`vertex()` 也可写,改变顶点位置(做"挥动旗帜"、"水底扭曲")。

### 2. uniform = "从 GDScript 暴露的参数"
```glsl
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.35;
uniform vec3  tint : source_color = vec3(1.0, 1.0, 1.0);
```
- `hint_range(min, max)`:在 Inspector 里出现一条滑块
- `source_color`:Inspector 显示色彩选择器(而不是 3 个数字)
- 默认值后写,等号赋值

从 GDScript 改:
```gdscript
material.set_shader_parameter("pulse_speed", 3.0)
```
**改 uniform 不会重新编译 shader**,接近免费,可以每帧改。

### 3. CRT 扫描线(scanline.gdshader)
核心:
```glsl
float scan = 0.5 + 0.5 * sin(uv.y * scanline_count * 3.14159);
float scan_factor = 1.0 - scanline_strength * (1.0 - scan);
COLOR.rgb *= scan_factor;
```
y 方向叠 sin → 高频明暗 → 看起来是横线。
搭配暗角(`1 - dist * vignette`)和色调(`tint`)就有 80 年代 CRT 味。

### 4. 水面波纹(water.gdshader)
两次 sin 叠加,频率不同 → 看着更"乱"自然:
```glsl
float wave = sin(uv.x * f * 6.28 + TIME * v)
           + 0.6 * sin(uv.y * f * 4.0 + TIME * v * 1.3);
```
`TIME` 让相位流动 → 动起来。

### 5. 脉冲发光(glow.gdshader)
距离场写法:
```glsl
float d = distance(uv, vec2(0.5));
float t = smoothstep(radius * 1.6, radius, d);
```
- `distance` 得到当前像素到中心的距离
- `smoothstep(edge1, edge0, x)`:**注意参数顺序**,这里 edge1 > edge0,得到 d 在 (radius~radius*1.6) 区间内从 1 衰减到 0
- `pow(t, falloff)` 调衰减锐度

### 6. 滚动彩虹(rainbow.gdshader)
HSV 转 RGB 的标准 GLSL 套路:
```glsl
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}
```
然后 `hue = fract(UV.x + TIME * speed)`,彩虹自动滚。

## ShaderMaterial 装到节点上
`.tscn` 里:
```
[sub_resource type="ShaderMaterial" id="mat_scan"]
shader = ExtResource("2_scan")

[node name="ScanlineRect" type="ColorRect" parent="."]
material = SubResource("mat_scan")
```
代码里:
```gdscript
var mat = ShaderMaterial.new()
mat.shader = preload("res://water.gdshader")
node.material = mat
```

## 改造练习

1. **加一个鼠标位置 uniform**:`uniform vec2 mouse;` + `material.set_shader_parameter("mouse", get_local_mouse_position())`。让 Glow 跟鼠标走。
2. **后处理**:把 4 个 shader 之一挂在一张全屏 ColorRect 上,放在最顶层 → 整个游戏画面被它套滤镜(CRT 全屏复古味)。
3. **顶点 shader**:`vertex()` 里写 `VERTEX.y += sin(VERTEX.x * 0.05 + TIME) * 8.0;`,旗帜飘扬。
4. **采样自己**:ColorRect 用 `back_buffer_copy` 节点暴露 `SCREEN_TEXTURE`,实现"扭曲后面的像素"(玻璃球、热浪)。
5. **3D shader**:`shader_type spatial;` + `ALBEDO = vec3(UV, 0.5);` 试试。

## 易踩坑

- **`smoothstep(edge0, edge1, x)` 参数顺序记不清** → 想成"x 从 edge0 走到 edge1,返回 0→1"。要反转就交换。
- **ColorRect 没纹理**,所以 shader 里读 `TEXTURE` / `texture(TEXTURE, UV)` 是黑色。给它 `texture` 属性挂一张图才有内容。
- shader 编译失败时 Godot 在 Output 面板报红字 —— **永远先看那里**,不要在 GDScript 端瞎找。
- `hint_range` 只是 UI 提示,**运行时不会自动夹值**。你得自己 `clamp` 或保证传入合法。
- `gl_compatibility` 渲染器不支持 `shader_type spatial` 的某些高级语法(如 SSR 相关)。本 demo 都用 canvas_item,安全。
- `TIME` 是从 **shader 启动**起算的,**不是节点存在的时间**,场景切换会归零。
