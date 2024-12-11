shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back;

instance uniform vec4 base_color : source_color = vec4(1.0);
instance uniform vec4 lerp_color : source_color = vec4(1.0);
instance uniform float lerp_fade_in : hint_range(0.0, 1.0) = 0.0;
instance uniform float lerp_wave : hint_range(0.0, 1.0) = 0.0;
instance uniform float lerp_wave_freq : hint_range(0.0, 10.0) = 1.0;
instance uniform float lerp_wave_offset : hint_range(0.0, 1.0) = 0.0;
instance uniform int lerp_wave_type : hint_range(0, 7) = 0; // 0: Sine, 1: Square, 2: Triangle, 3: Sawtooth, 4: Bounce, 5: Elastic, 6: Circular, 7: Exponential
instance uniform float lerp_displace_normal : hint_range(-1.0, 1.0) = 0.0;
instance uniform bool bool_use_disp_lerp = false;
instance uniform float lerp_warp : hint_range(0.0, 1.0) = 0.0;
instance uniform float warp_freq : hint_range(0.0, 10.0) = 1.0;
instance uniform float warp_offset : hint_range(0.0, 1.0) = 0.0;
instance uniform float time_scale : hint_range(0.0, 10.0) = 1.0;

varying vec3 vertex_pos;
varying vec3 vertex_normal;

void vertex() {
    vertex_pos = VERTEX;
    vertex_normal = NORMAL;
}

float wave(float value, int type) {
    float t = fract(value / (2.0 * PI));
    switch(type) {
        case 0: return sin(value);
        case 1: return sign(sin(value));
        case 2: return abs(2.0 * t - 1.0) * 2.0 - 1.0;
        case 3: return t * 2.0 - 1.0;
        case 4: return sin(value * PI) * (1.0 - t);
        case 5: return sin(-13.0 * (t + 1.0) * PI) * pow(2.0, -10.0 * t) + 1.0;
        case 6: return sqrt(1.0 - pow(t - 1.0, 2.0));
        case 7: return t == 0.0 ? 0.0 : pow(2.0, 10.0 * (t - 1.0));
        default: return sin(value);
    }
}

void fragment() {
    float time = TIME * time_scale;
    
    // Calculate wave effect
    float wave_value = wave((vertex_pos.y + lerp_wave_offset * time) * lerp_wave_freq, lerp_wave_type);
    float wave_intensity = lerp_wave * 0.5 * (wave_value + 1.0);
    
    // Calculate warp effect
    vec2 warp = vec2(
        wave(vertex_pos.x * warp_freq + warp_offset * time, 0),
        wave(vertex_pos.y * warp_freq + warp_offset * time, 0)
    ) * lerp_warp;
    
    // Apply warp to UV
    vec2 warped_uv = UV + warp;
    
    // Lerp between base color and lerp color
    vec4 final_color = mix(base_color, lerp_color, lerp_fade_in);
    
    // Apply wave intensity
    final_color = mix(final_color, lerp_color, wave_intensity);
    
    ALBEDO = final_color.rgb;
    ALPHA = final_color.a;
    
    // Apply normal displacement if enabled
    if (bool_use_disp_lerp) {
        vec3 displaced_normal = normalize(vertex_normal + vec3(lerp_displace_normal));
        NORMAL = (VIEW_MATRIX * vec4(displaced_normal, 0.0)).xyz;
    }
}