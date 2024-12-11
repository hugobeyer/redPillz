shader_type spatial;

#include "res://_shaders/custom/include/custom_frag_incs.gdshaderinc"

varying vec3 vertex_pos;
varying vec4 vertex_color;
varying vec3 vertex_normal;
varying vec2 vertex_uv;



float wave(vec3 position, vec2 uv, vec3 gradient_dir, float value, int type) {
    switch(type) {
        case 0: return sin(value);
        case 1: return cos(value);
        case 2: return clamp(tan(value), -1.0, 1.0);
        case 3: return sign(sin(value));
        case 4: return fract(value / (2.0 * PI)) * 2.0 - 1.0;
        case 5: return abs(fract(value / PI) * 2.0 - 1.0) * 2.0 - 1.0;
        case 6: { // Less tiling noise
            vec3 p = vec3(position * 0.01); // Scale down to reduce tiling
            return fract(sin(dot(p, vec3(12.9898, 78.233, 45.5432))) * 43758.5453) * 2.0 - 1.0;
        }
        case 7: return sin(value) * exp(-fract(value / (2.0 * PI)));
        case 8: { // Less tiling UV-based wave
            float scale = 0.1; // Adjust this to control tiling
            return sin(uv.x * value * scale) * cos(uv.y * value * scale);
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

void fragment() {
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
    vec3 gradient_color = mix(color_bottom.rgb, color_top.rgb, clamp(t, 0.0, 1.0));

    // Blend gradient with vertex color
    vec3 base_color = mix(gradient_color, vertex_color.rgb, vertex_color_mix);

    vec3 final_color = base_color;

    // Apply blend modes
    if (blend_mode == 0) { // Mix blend
        // Already done in the previous step
    } else if (blend_mode == 1) { // Additive blend
        final_color += vertex_color.rgb * vertex_color_mix;
    } else if (blend_mode == 2) { // Multiply blend
        final_color *= mix(vec3(1.0), vertex_color.rgb, vertex_color_mix);
    } else if (blend_mode == 3) { // Screen blend
        final_color = vec3(1.0) - (vec3(1.0) - final_color) * (vec3(1.0) - vertex_color.rgb * vertex_color_mix);
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
    final_color = mix(final_color, lerp_color.rgb, overlay_intensity);

    ALBEDO = final_color;

    // Add the overlay color as emission to make it unlit
    EMISSION = lerp_color.rgb * overlay_intensity;
}

void light() {
    // Diffuse lighting
    float ndotl = dot(NORMAL, LIGHT);
    float wrapped_ndotl = (ndotl + diffuse_wrap) / (1.0 + diffuse_wrap);
    float diffuse = wrapped_ndotl;
    diffuse = smoothstep(-diffuse, 1.0, diffuse + diffuse_offset);
    diffuse = clamp((diffuse - 0.5) * diffuse_contrast + 0.5, 0.0, 1.0);
    diffuse = clamp(diffuse, 0.0, 1.0);

    // Specular lighting
    vec3 half_dir = normalize(VIEW + LIGHT);
    float ndoth = dot(NORMAL, half_dir);
    float spec = pow(max(ndoth + specular_offset, 0.0), mix(1.0, 128.0, specular_size));
    spec = smoothstep(-specular_smoothness, 1.0, spec);
    spec *= specular_intensity;

    // Fresnel
    float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)) + fresnel_offset, fresnel_power);
    fresnel = clamp((fresnel - 0.5) * fresnel_contrast + 0.5, 0.0, 1.0);

    // Apply lighting components
    vec3 diffuse_light = ALBEDO * diffuse;
    vec3 specular_light = specular_color * spec;
    vec3 combined_light = diffuse_light + specular_light;

    // Apply fresnel
    combined_light = mix(combined_light, fresnel_color, fresnel * fresnel_intensity);

    // Apply soft clamping
    combined_light = vec3(1.0) - exp(-combined_light * 0.6);

    // Apply light color and attenuation
    vec3 final_light = combined_light * LIGHT_COLOR * ATTENUATION;

    DIFFUSE_LIGHT += final_light;
}

render_mode depth_draw_always, cull_back, diffuse_lambert_wrap, specular_schlick_ggx;