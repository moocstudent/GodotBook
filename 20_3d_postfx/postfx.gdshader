// 全屏后处理:横向色差 + 暗角 + 扫描线
// 用法:挂在最顶层 CanvasLayer 下的全屏 ColorRect 上,SCREEN_TEXTURE 自动拿到底层 3D 渲染结果
shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear;

uniform float chroma_amount : hint_range(0.0, 0.02) = 0.006;
uniform float vignette      : hint_range(0.0, 1.0)  = 0.45;
uniform float scanline_str  : hint_range(0.0, 0.6)  = 0.12;
uniform float scanline_freq : hint_range(100.0, 1200.0) = 600.0;

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 center = uv - 0.5;
    float dist = length(center);

    // 1) RGB 通道偏移做色差
    vec2 dir = center * chroma_amount;
    float r = texture(SCREEN_TEXTURE, uv + dir).r;
    float g = texture(SCREEN_TEXTURE, uv).g;
    float b = texture(SCREEN_TEXTURE, uv - dir).b;
    vec3 col = vec3(r, g, b);

    // 2) 扫描线
    float scan = 0.5 + 0.5 * sin(uv.y * scanline_freq);
    col *= 1.0 - scanline_str * (1.0 - scan);

    // 3) 暗角
    col *= 1.0 - dist * vignette * 1.4;

    COLOR.rgb = col;
    COLOR.a = 1.0;
}
