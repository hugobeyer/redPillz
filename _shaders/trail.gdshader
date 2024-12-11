shader_type spatial;
render_mode blend_add, cull_disabled, unshaded;

uniform vec4 trail_color : source_color = vec4(1.0, 0.6, 0.2, 0.6);
uniform float trail_width : hint_range(0.0, 2.0) = 0.2;
uniform float trail_fade : hint_range(0.0, 1.0) = 0.5;

void vertex() {
    // UV.x is along the trail length, UV.y is across the trail width
    float fade = 1.0 - UV.x; // Fade out towards the end of the trail
    
    // Apply width and fade
    VERTEX *= trail_width * (fade * (1.0 - trail_fade) + trail_fade);
}

void fragment() {
    // Calculate fade based on trail length
    float fade = 1.0 - UV.x;
    
    // Apply color with fade
    ALBEDO = trail_color.rgb;
    ALPHA = trail_color.a * fade;
} 