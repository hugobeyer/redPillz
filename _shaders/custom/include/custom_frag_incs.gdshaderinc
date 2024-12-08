uniform vec4 color_top : source_color = vec4(0, 0, 1.0, 1.0);
uniform vec4 color_bottom : source_color = vec4(1, 0.55, 0.120, 1.0);
uniform vec3 specular_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 fresnel_color : source_color = vec3(0.0,1.0, 0.0);



instance uniform float alpha : hint_range(0.0, 1.0, 0.001);
instance uniform vec4 lerp_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform float lerp_wave : hint_range(0.0, 1.0, 0.001) = 0.0;
instance uniform float lerp_wave_freq : hint_range(0.0, 100.0, 0.01) = 1.0;
instance uniform float lerp_wave_offset : hint_range(-32, 32.0, 0.01) = 0.0;
instance uniform int lerp_wave_type : hint_range(0, 16) = 0;
instance uniform float lerp_displace_normal : hint_range(-1.0, 1.0) = 0.0;
instance uniform float lerp_wave_contrast : hint_range(0.0, 4.0, 0.01) = 1.0;
instance uniform float wave_range_lerp : hint_range(-5.0, 5.0) = 0.0;

uniform float vertex_color_mix : hint_range(0.0, 1.0) = 0.0;
uniform int blend_mode : hint_range(0, 3) = 0;
uniform int gradient_rotation_mode : hint_range(0, 2) = 1;
uniform float gradient_offset : hint_range(-1.0, 1.0) = 0.0;
uniform float gradient_smoothness : hint_range(0.0, 10.0) = 1.0;

uniform float diffuse_contrast : hint_range(0.0, 8.0) = 1.0;
uniform float diffuse_wrap : hint_range(0.0, 2.0) = 0.0;
uniform float diffuse_offset : hint_range(-1.0, 1.0) = 0.0;

uniform float specular_intensity : hint_range(0.0, 2.0) = 1;
uniform float specular_size : hint_range(0.0, 1.0) = 0.2;
uniform float specular_smoothness : hint_range(0.0, 1.0) = 0.25;
uniform float specular_offset : hint_range(-1.0, 1.0) = 0.0;

uniform float fresnel_power : hint_range(-10.0, 10.0) = 4;
uniform float fresnel_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float fresnel_contrast : hint_range(0.0, 4.0) = 2.0;
uniform float fresnel_offset : hint_range(-1.0, 1.0) = 0.25;
