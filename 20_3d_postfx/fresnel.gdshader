// Spatial shader:菲涅尔边缘发光,经典科幻 / 卡通边缘
shader_type spatial;

uniform vec3  base_color : source_color = vec3(0.3, 0.5, 0.9);
uniform vec3  rim_color  : source_color = vec3(1.0, 0.7, 0.3);
uniform float rim_power  : hint_range(0.3, 8.0) = 2.5;
uniform float rim_boost  : hint_range(0.0, 3.0) = 1.2;

void fragment() {
    // NORMAL = 当前像素的法线(view space),VIEW = 摄像机指向像素方向
    // 1 - dot(N, V) → 边缘趋向 1,正对方向趋向 0
    float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);

    ALBEDO = mix(base_color, rim_color, fresnel);
    EMISSION = rim_color * fresnel * rim_boost;   // 自发光,亮的部分受 light 影响小
    METALLIC = 0.1;
    ROUGHNESS = 0.35;
}
