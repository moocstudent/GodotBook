// 简单"水面":随时间起伏的正弦波 + 颜色梯度
shader_type canvas_item;

uniform vec3  shallow : source_color = vec3(0.4, 0.85, 0.95);
uniform vec3  deep    : source_color = vec3(0.05, 0.25, 0.55);
uniform float wave_amp  : hint_range(0.0, 0.2)   = 0.05;
uniform float wave_freq : hint_range(0.5, 10.0)  = 3.5;
uniform float speed     : hint_range(0.0, 4.0)   = 1.2;

void fragment() {
    vec2 uv = UV;

    // 用 TIME 让水面随时间动
    float wave = sin(uv.x * wave_freq * 6.28318 + TIME * speed)
               + 0.6 * sin(uv.y * wave_freq * 4.0 + TIME * speed * 1.3);
    wave *= wave_amp;

    // 颜色按 y(深度)从浅到深插值,加上波纹高光
    float depth = uv.y + wave;
    vec3 col = mix(shallow, deep, clamp(depth, 0.0, 1.0));

    // 顶部加白色泡沫线
    float foam = smoothstep(0.04, 0.0, uv.y + wave);
    col = mix(col, vec3(1.0), foam * 0.7);

    COLOR.rgb = col;
}
