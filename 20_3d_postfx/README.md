# Demo 20 — 3D Spatial Shader + 后处理

3D 上的两种 shader 作用层级:**物体表面 (spatial)** 和 **全屏后处理 (canvas_item + SCREEN_TEXTURE)**。立方体和球用同一份 fresnel rim 着色,头顶全屏 ColorRect 加横向色差 + 扫描线 + 暗角。

## 跑起来

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path .
```

- **T** 切 post-fx 开关(对比有/无)
- **1/2/3** 切色差强度档位
- **Q** 循环切菲涅尔 power
- ESC 退出

## 学到什么

### 1. shader_type spatial(3D 表面着色)
```glsl
shader_type spatial;
void fragment() {
    ALBEDO = vec3(...);        // 基础颜色
    METALLIC = 0.1;
    ROUGHNESS = 0.4;
    EMISSION = vec3(...);      // 自发光
    NORMAL_MAP = ...;          // 法线贴图(本 demo 没用)
    ALPHA = 1.0;
}
```
内置变量(只列最常用):
- `VERTEX` (vec3) — 顶点位置(view space)
- `NORMAL` (vec3) — 法线
- `VIEW` (vec3) — 从像素指向摄像机的方向
- `UV` (vec2) — 第一套 UV
- `TIME` (float) — 全局时间

### 2. 菲涅尔(Fresnel)效应
**侧光打到表面的边缘亮度高于正面** —— 真实玻璃、水、肥皂泡、还有所有"卡通边缘描边"都用它。
```glsl
float fresnel = pow(1.0 - dot(NORMAL, VIEW), rim_power);
ALBEDO = mix(base_color, rim_color, fresnel);
EMISSION = rim_color * fresnel * rim_boost;
```
- `dot(N, V)`:法线与视线夹角余弦。正对镜头 = 1,边缘 = 0
- `1 - dot()` 翻转,边缘 = 1
- `pow(_, power)` 调"边缘有多窄":power 大 = 细边,power 小 = 大范围

### 3. WorldEnvironment 是什么
3D 场景的"环境总开关":天空、雾、tonemap、bloom、SSAO、SSR、glow……全在它的 `environment` 属性下。**每个 3D 场景应当只有一个**(多了被忽略)。

本 demo 设了:
- `background_mode = 2` (Sky)
- `tonemap_mode = 2` (Filmic) + `tonemap_exposure = 1.1`
- `ambient_light_*` 弱环境光,让阴影不死黑

### 4. tonemap = HDR → SDR 的映射函数
3D 渲染内部是 HDR(亮度可以 > 1.0),屏幕是 SDR(0~1)。tonemap 把高亮压回可显示范围。
- `LINEAR` (0):直接 clamp,亮处死白
- `REINHARD` (1):简单除法,温和但偏灰
- `FILMIC` (2):电影感S 曲线,黑亮分明
- `ACES` (3):工业标准

试着改 `tonemap_mode = 3`,观感差异明显。

### 5. 后处理用 canvas_item shader + SCREEN_TEXTURE
3D 渲染完毕后,最顶层 CanvasLayer 的 ColorRect 覆盖整个屏幕,它的 shader 可以采样 `SCREEN_TEXTURE`(此刻屏幕上已经画完的内容)。

```glsl
shader_type canvas_item;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear;

void fragment() {
    vec3 col = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
    COLOR.rgb = col * effect_factor;
}
```
- `hint_screen_texture` 标记是关键:Godot 自动在 shader 跑之前把屏幕复制一份给你采样
- `SCREEN_UV` 是当前像素在屏幕上的归一化坐标(全屏 ColorRect 下基本等于 UV)

### 6. 色差(Chromatic Aberration)
真实镜头玻璃对 R/G/B 折射不同 → 边缘有彩色"毛边":
```glsl
vec2 dir = (SCREEN_UV - 0.5) * chroma_amount;
float r = texture(SCREEN_TEXTURE, SCREEN_UV + dir).r;
float g = texture(SCREEN_TEXTURE, SCREEN_UV).g;
float b = texture(SCREEN_TEXTURE, SCREEN_UV - dir).b;
COLOR.rgb = vec3(r, g, b);
```
偏移量与到屏幕中心的距离正相关 → 越靠边越分离,中心干净。这是廉价但效果立竿见影的"电影感"滤镜。

### 7. 多层 CanvasLayer
```
WorldEnvironment + 3D 节点 + Camera  ← 3D 层
PostFX (CanvasLayer, layer=10)
└── PostRect                          ← 全屏 post 滤镜
HUD (CanvasLayer, layer=20)
└── Label                             ← UI 文字(不被 post 影响)
```
**layer 数字大的画在上面**。HUD 在 PostFX 之上,所以文字不被色差扭曲 —— 这是大部分游戏的正确做法,UI 应该"在滤镜之外"。

## gl_compatibility 渲染器的局限

| 特性 | gl_compatibility | mobile/forward+ |
|------|------------------|-----------------|
| tonemap | ✓ | ✓ |
| 简单后处理 (本 demo) | ✓ | ✓ |
| Glow/Bloom(WorldEnvironment 自带) | ✗ | ✓ |
| SSAO / SSR / SDFGI | ✗ | ✓ (forward+) |
| Compositor effects | ✗ | ✓ |

要做更进阶的 bloom / SSAO,切到 mobile 渲染器(在 `project.godot` 改 `renderer/rendering_method`)。本仓默认 gl_compatibility,牺牲质量换 Android 老机兼容。

## 改造练习

1. **径向模糊**:post shader 里采样多次沿屏幕中心方向偏移的 SCREEN_TEXTURE,平均 → "急刹车"效果。
2. **像素化**:`uv = floor(SCREEN_UV * pixel_size) / pixel_size`。
3. **CRT 弯曲**:让 SCREEN_UV 经过 barrel distortion:`uv = uv + (uv - 0.5) * dot(uv - 0.5, uv - 0.5) * 0.1`。
4. **物体卡通描边**:spatial shader 不写在像素 fragment,而是写在 `vertex()` 里 push 法线方向 → 反 culling 第二遍画黑。或用 SCREEN_TEXTURE 在 post 处用 Sobel 边缘检测。
5. **闪光受击**:被击中时把整个 `EMISSION` 乘 (1 + flash),0.2s 内 Tween 回 1。
6. **bloom**:切到 mobile 渲染器,WorldEnvironment → Glow → 勾选,即刻有 bloom。

## 易踩坑

- `SCREEN_TEXTURE` **必须**带 `hint_screen_texture` 才工作,否则采样到空。
- canvas_item shader 里的 `COLOR.a` 默认 0(因为节点 modulate 是透明的) —— 全屏 post 必须显式 `COLOR.a = 1.0`,否则看不见。
- 改了 spatial shader 的 uniform 颜色后,**编辑器 viewport 不一定立刻更新**;运行游戏看真实效果。
- `EMISSION` 在 gl_compatibility 下也能用,但因为没有 bloom,看着只是亮一点,不会"发光溢出"。
- 后处理 ColorRect 必须 `mouse_filter = MOUSE_FILTER_IGNORE`(2),否则鼠标事件被它吞了,下面的按钮失灵。
- `tonemap_exposure` 高了画面过曝;低了死黑。0.8-1.4 是合理区间。
- 不要在 spatial shader 的 `fragment` 里读 `TIME` 大量做计算 —— GPU 每个像素都跑,性能集中关注 vertex 阶段。
