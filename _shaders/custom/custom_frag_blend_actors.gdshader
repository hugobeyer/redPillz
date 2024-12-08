shader_type spatial;

#include "res://_shaders/custom/include/custom_frag_incs.gdshaderinc"


varying vec3 vertex_pos;  // Change from vec4 to vec3
varying vec4 vertex_color;
varying vec3 vertex_normal;  // Change from vec4 to vec3
varying vec2 vertex_uv;

float apply_contrast(float value, float contrast) {
    return clamp(((value - 0.5) * contrast) + 0.5, 0.0, 1.0);
}

// Remove or comment out this function if it's not used elsewhere
// float apply_soft_steps(float value, int steps, float softness) {
//     // This function is no longer needed
// }

vec3 soft_clamp(vec3 x, float a) {
    return vec3(1.0) - exp(-a * x);
}

float calculate_fresnel(vec3 normal, vec3 view, float power, float contrast, float offset) {
    float fresnel = pow(1.0 - abs(dot(normal, view)) + offset, power);
    return apply_contrast(fresnel, contrast);
}

vec3 apply_fresnel(vec3 base_color, vec3 fresnelColor, float fresnel_value, float intensity) {
    return mix(base_color, fresnelColor, fresnel_value * intensity);
}

float wave(vec3 position, vec2 uv, vec3 gradient_dir, float value, int type) {
    switch(type) {
        case 0: return sin(value);
        case 1: return cos(value);
        case 2: return clamp(tan(value), -1.0, 1.0);
        case 3: return sign(sin(value));
        case 4: return fract(value / (2.0 * PI)) * 2.0 - 1.0;
        case 5: return abs(fract(value / PI) * 2.0 - 1.0) * 2.0 - 1.0;
        case 6: { // Less tiling noise
            vec3 p = vec3(position-gradient_dir * 0.01 * value); // Scale down to reduce tiling
            return fract(sin(dot(p, vec3(2.9898, 17.233, 8.5432))) * .8) * 2.0 - 1.0;
        }
        case 7: return sin(value) * exp(-fract(value / (2.0 * PI)));
        case 8: { // Less tiling UV-based wave
            float scale = 1.1; // Adjust this to control tiling
            return sin(gradient_dir.x + value * scale) * cos(uv.y + value * scale);
        }
        case 9: {
            vec3 cross_vec = cross(gradient_dir, normalize(position));
            return sin(dot(cross_vec, position) * value);
        }
        case 10: return sin(value) * sin(value * 2.0);
        case 11: return clamp(sin(value) + sin(value * 2.0) * 0.5, -1.0, 1.0);
        case 12: return sin(value) * (1.0 - fract(value / PI));
        case 13: return sin(value) * sin(value * 3.0) * cos(value * 5.0);
        case 14: return sin(sin(value) * 5.0);
        case 15: return sin(value) * (1.0 - exp(-5.0 * fract(value / (2.0 * PI))));
    }
    return sin(value); // Default case
}

void vertex() {
    vertex_pos = VERTEX;
    vertex_color = COLOR;
    vertex_normal = NORMAL;
    vertex_uv = UV;

    // Apply displacement without any wave influence
    VERTEX += NORMAL * lerp_displace_normal;
}

float saturate(float x) {
    return clamp(x, 0.0, 1.0);
}

void fragment() {// Your existing shader code here

    vec3 gradient_direction;
    if (gradient_rotation_mode == 0) {
        gradient_direction = vec3(1.0, 0.0, 0.0); // X-axis
    } else if (gradient_rotation_mode == 1) {
        gradient_direction = vec3(0.0, 1.0, 0.0); // Y-axis
    } else {
        gradient_direction = vec3(0.0, 0.0, 1.0); // Z-axis
    }

    // Calculate gradient
    float t = dot(vertex_pos, gradient_direction);
    t = smoothstep(-gradient_smoothness, gradient_smoothness, t + gradient_offset);
    vec4 gradient_color = mix(color_bottom, color_top, clamp(t, 0.0, 1.0));

    // Blend gradient with vertex color
    vec4 base_color = mix(gradient_color, vertex_color, vertex_color_mix);
    float base_alpha = mix(gradient_color.x, vertex_color.x, alpha);

    vec4 final_color = base_color;
	final_color.a = base_alpha;
    // Apply blend modes
    if (blend_mode == 0) { // Mix blend
        // Already done in the previous step
    } else if (blend_mode == 1) { // Additive blend
        final_color.rgb += vertex_color.rgb * vertex_color_mix;
        final_color.a = min(base_color.a, vertex_color.a * alpha);
    } else if (blend_mode == 2) { // Multiply blend
        final_color *= mix(vec4(1.0), vertex_color, vertex_color_mix);
    } else if (blend_mode == 3) { // Screen blend
        final_color.rgb = vec3(1.0) - (vec3(1.0) - final_color.rgb) * (vec3(1.0) - vertex_color.rgb * vertex_color_mix);
        final_color.a = min(base_color.a, vertex_color.a * alpha);
    }

    float overlay_intensity = 0.0;

    // Only calculate wave if lerp_wave is not 0
    if (lerp_wave != 0.0) {
        // Calculate wave effect
        float wave_value = wave(vertex_pos, vertex_uv, gradient_direction,
                                dot(vertex_pos, gradient_direction) * lerp_wave_freq + lerp_wave_offset * TIME,
                                lerp_wave_type);

        // Lerp wave value from [0,1] to [-1,1] based on wave_range_lerp
        wave_value = mix(wave_value, wave_value * 2.0 - 1.0, wave_range_lerp);

        // Apply contrast
        wave_value = clamp((wave_value - 0.5) * lerp_wave_contrast + 0.5, 0.0, 1.0);

        float wave_intensity = wave_value * lerp_wave;

        // Calculate overlay intensity
        overlay_intensity = clamp(lerp_color.a * wave_intensity, 0.0, 1.0);
    }

    // Apply lerp color with wave effect
    final_color.rgb = mix(final_color.rgb, lerp_color.rgb, overlay_intensity);

    ALBEDO = final_color.rgb;
    ALPHA = final_color.a;

    // Add the overlay color as emission to make it unlit
    EMISSION = lerp_color.rgb * overlay_intensity;

    // Remove normal perturbation
    // NORMAL remains as calculated in the vertex shader
}

void light() {
    // Diffuse lighting
    float ndotl = dot(NORMAL, LIGHT);
    float wrapped_ndotl = (ndotl + diffuse_wrap) / (1.0 + diffuse_wrap);
    float diffuse = wrapped_ndotl;
    diffuse = smoothstep(-diffuse, 1.0, diffuse + diffuse_offset);
    diffuse = apply_contrast(diffuse, diffuse_contrast);
    diffuse = clamp(diffuse, 0.0, 1.0);

    // Specular lighting
    vec3 half_dir = normalize(VIEW + LIGHT);
    float ndoth = dot(NORMAL, half_dir);
    float spec = pow(max(ndoth + specular_offset, 0.0), mix(1.0, 128.0, specular_size));
    spec = smoothstep(-specular_smoothness, 1.0, spec);
    spec *= specular_intensity;

    // Fresnel
    float fresnel = calculate_fresnel(NORMAL, VIEW, fresnel_power, fresnel_contrast, fresnel_offset);

    // Apply lighting components
    vec3 diffuse_light = ALBEDO * diffuse;
    vec3 specular_light = specular_color * spec;
    vec3 combined_light = diffuse_light + specular_light;

    // Apply fresnel
    combined_light = apply_fresnel(combined_light, fresnel_color, fresnel, fresnel_intensity);

    // Apply soft clamping
    combined_light = soft_clamp(combined_light, 0.6);

    // Apply light color and attenuation
    vec3 final_light = combined_light * LIGHT_COLOR * ATTENUATION;

    DIFFUSE_LIGHT += final_light;
}

render_mode depth_draw_always, depth_prepass_alpha, vertex_lighting, specular_schlick_ggx;