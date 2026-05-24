#[compute]
#version 450

// 本地工作组大小:每个 dispatch 一组 64 个线程
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

// SSBO(Shader Storage Buffer Object):CPU/GPU 之间传大数组
// 每个 boid: pos.xy, vel.xy = 4 个 float
layout(set = 0, binding = 0, std430) restrict buffer BoidBuffer {
    float data[];
} boids;

// uniform 参数(单个值)用 push constant 传,这里用一个小 UBO
layout(set = 0, binding = 1, std430) restrict buffer ParamBuffer {
    float delta;
    float boid_count;
    float bounds_x;
    float bounds_y;
    float sep_weight;
    float align_weight;
    float cohesion_weight;
    float max_speed;
    float neighbor_radius;
    float _pad0;
    float _pad1;
    float _pad2;
} params;

void main() {
    uint i = gl_GlobalInvocationID.x;
    uint n = uint(params.boid_count);
    if (i >= n) {
        return;
    }

    vec2 pos = vec2(boids.data[i * 4u + 0u], boids.data[i * 4u + 1u]);
    vec2 vel = vec2(boids.data[i * 4u + 2u], boids.data[i * 4u + 3u]);

    vec2 separation = vec2(0.0);
    vec2 alignment = vec2(0.0);
    vec2 cohesion = vec2(0.0);
    int neighbors = 0;

    float r = params.neighbor_radius;

    // 经典 boids:对所有其他个体求和(O(n^2),GPU 并行下也能撑几千个)
    for (uint j = 0u; j < n; j++) {
        if (j == i) continue;
        vec2 other_pos = vec2(boids.data[j * 4u + 0u], boids.data[j * 4u + 1u]);
        vec2 diff = pos - other_pos;
        float d = length(diff);
        if (d > 0.0 && d < r) {
            separation += normalize(diff) / d;     // 越近推力越大
            vec2 other_vel = vec2(boids.data[j * 4u + 2u], boids.data[j * 4u + 3u]);
            alignment += other_vel;
            cohesion += other_pos;
            neighbors++;
        }
    }

    if (neighbors > 0) {
        alignment /= float(neighbors);
        cohesion = cohesion / float(neighbors) - pos;
        vel += separation * params.sep_weight;
        vel += alignment  * params.align_weight  * 0.05;
        vel += cohesion   * params.cohesion_weight * 0.02;
    }

    // 限速
    float speed = length(vel);
    if (speed > params.max_speed) {
        vel = vel / speed * params.max_speed;
    }
    if (speed < 20.0) {
        // 给个最小速度,避免停住
        vel = (speed > 0.0 ? vel / speed : vec2(1.0, 0.0)) * 20.0;
    }

    pos += vel * params.delta;

    // 环绕边界(穿屏)
    if (pos.x < 0.0) pos.x += params.bounds_x;
    if (pos.x > params.bounds_x) pos.x -= params.bounds_x;
    if (pos.y < 0.0) pos.y += params.bounds_y;
    if (pos.y > params.bounds_y) pos.y -= params.bounds_y;

    boids.data[i * 4u + 0u] = pos.x;
    boids.data[i * 4u + 1u] = pos.y;
    boids.data[i * 4u + 2u] = vel.x;
    boids.data[i * 4u + 3u] = vel.y;
}
