// 经典 CRT 扫描线 + 屏幕轻微弯曲 + 颜色暖偏
shader_type canvas_item;

uniform float scanline_strength : hint_range(0.0, 1.0) = 0.35;
uniform float scanline_count    : hint_range(50.0, 800.0) = 240.0;
uniform float vignette          : hint_range(0.0, 1.0) = 0.4;
uniform vec3  tint              : source_color = vec3(1.05, 0.95, 0.85);

void fragment() {
    vec2 uv = UV;

    // 1) 屏幕中央向外的渐变:UV 越靠边越暗 -> 暗角
    vec2 center = uv - 0.5;
    float dist = length(center);
    float v = 1.0 - dist * vignette * 1.6;

    // 2) 扫描线:在 y 方向叠一道 sin
    float scan = 0.5 + 0.5 * sin(uv.y * scanline_count * 3.14159);
    float scan_factor = 1.0 - scanline_strength * (1.0 - scan);

    // 3) 输出
    COLOR.rgb *= tint * v * scan_factor;
}
