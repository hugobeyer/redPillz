shader_type spatial;
render_mode diffuse_lambert, cull_back, depth_draw_opaque;

uniform int grid_type : hint_range(0, 1) = 0; // 0 for square, 1 for hexagon
uniform vec2 grid_scale = vec2(1.0, 1.0);
uniform float border_size : hint_range(0.0, 0.5) = 0.1;
uniform float border_gradient : hint_range(0.0, 0.5) = 0.05;
uniform vec3 color1 : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 color2 : source_color = vec3(0.0, 0.0, 0.0);
uniform vec3 player_position = vec3(0.0, 0.0, 0.0);
uniform float min_radius = 1.0;
uniform float max_radius = 10.0;
uniform float radius_scale = 1.0;
uniform vec3 pattern_color : source_color = vec3(0.5, 0.5, 0.5);
uniform float pattern_scale : hint_range(0.1, 10.0) = 1.0;
uniform float pattern_frequency : hint_range(0.1, 10.0) = 1.0;
uniform float time = 0.0;

varying vec3 world_pos;

float square_grid(vec2 uv) {
    vec2 grid = fract(uv) - 0.5;
    return length(max(abs(grid) - border_size, 0.0));
}

float hex_grid(vec2 uv) {
    vec2 r = vec2(1.0, 1.73);
    vec2 h = r * 0.5;
    vec2 a = mod(uv, r) - h;
    vec2 b = mod(uv - h, r) - h;
    return length(a - sign(a.x + a.y) * min(abs(a.x), abs(a.y))) - border_size;
}

float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

float checker(vec2 uv) {
    vec2 gridUV = floor(uv);
    return mod(gridUV.x + gridUV.y, 2.0);
}

float ramp_x(vec2 uv) {
    return fract(uv.x);
}

float ramp_y(vec2 uv) {
    return fract(uv.y);
}

float overlay(float base, float blend) {
    return base < 0.5 ? (2.0 * base * blend) : (1.0 - 2.0 * (1.0 - base) * (1.0 - blend));
}

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec2 plane_uv = world_pos.xz * grid_scale;
    float grid_distance = grid_type == 1 ? hex_grid(plane_uv) : square_grid(plane_uv);

    float border = smoothstep(0.0, border_gradient, grid_distance);
    vec3 grid_color = mix(color1, color2, border);

    vec2 to_player = (world_pos.xz - player_position.xz) * radius_scale;
    float distance_from_player = length(to_player);
    float radial_mask = 1.0 - smoothstep(min_radius, max_radius, distance_from_player);

    vec2 pattern_uv = plane_uv * pattern_scale;
    vec2 cell = floor(pattern_uv);
    float cell_random = random(cell);

    float pattern0 = checker(pattern_uv);

    float pattern1, pattern2;
    if (cell_random < 0.33) {
        pattern1 = ramp_x(pattern_uv);
        pattern2 = ramp_y(pattern_uv);
    } else if (cell_random < 0.66) {
        pattern1 = ramp_y(pattern_uv);
        pattern2 = checker(pattern_uv);
    } else {
        pattern1 = checker(pattern_uv);
        pattern2 = ramp_x(pattern_uv);
    }

    float overlaid_pattern = overlay(pattern1, pattern2);
    float final_pattern = mix(pattern0, overlaid_pattern, radial_mask);

    vec3 pattern = mix(vec3(1.0), pattern_color, final_pattern);

    vec3 final_color = min(grid_color, pattern);

    ALBEDO = final_color;
}