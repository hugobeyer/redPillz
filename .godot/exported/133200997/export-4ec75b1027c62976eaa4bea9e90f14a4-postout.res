RSRC                    VisualShader            ��������                                            B      resource_local_to_scene    resource_name    output_port_for_preview    default_input_values    expanded_output_ports    linked_parent_graph_frame    parameter_name 
   qualifier    hint    min    max    step    default_value_enabled    default_value    script    input_name    size    expression 	   constant    op_type    code    graph_offset    mode    modes/blend    flags/skip_vertex_transform    flags/unshaded    flags/light_only    flags/world_vertex_coords    nodes/vertex/0/position    nodes/vertex/connections    nodes/fragment/0/position    nodes/fragment/2/node    nodes/fragment/2/position    nodes/fragment/5/node    nodes/fragment/5/position    nodes/fragment/6/node    nodes/fragment/6/position    nodes/fragment/6/size    nodes/fragment/6/input_ports    nodes/fragment/6/output_ports    nodes/fragment/6/expression    nodes/fragment/7/node    nodes/fragment/7/position    nodes/fragment/8/node    nodes/fragment/8/position    nodes/fragment/9/node    nodes/fragment/9/position    nodes/fragment/10/node    nodes/fragment/10/position    nodes/fragment/connections    nodes/light/0/position    nodes/light/connections    nodes/start/0/position    nodes/start/connections    nodes/process/0/position    nodes/process/connections    nodes/collide/0/position    nodes/collide/connections    nodes/start_custom/0/position    nodes/start_custom/connections     nodes/process_custom/0/position !   nodes/process_custom/connections    nodes/sky/0/position    nodes/sky/connections    nodes/fog/0/position    nodes/fog/connections        -   local://VisualShaderNodeFloatParameter_rsoea f      $   local://VisualShaderNodeInput_e8rfl �      )   local://VisualShaderNodeExpression_38i1e 	      -   local://VisualShaderNodeColorParameter_jwagy �      ,   local://VisualShaderNodeFloatConstant_qlou0       .   local://VisualShaderNodeVectorDecompose_50qu7 K      ,   local://VisualShaderNodeVectorCompose_jk5ym �      !   res://_shaders/post/postout.tres �         VisualShaderNodeFloatParameter             outline_size          
        �B                 �?         VisualShaderNodeInput          
   screen_uv          VisualShaderNodeExpression       
     >D  fD      C  vec4 original_color = texture(TEXTURE, SCREEN_UV);
float threshold = 0.001;
if (original_color.a > 0.0) {
    result = original_color.rgba;  // Only return the RGB color channel
} else {
    
    bool outline = false;

    for (float x = -outline_size; x <= outline_size; x++) {
        for (float y = -outline_size; y <= outline_size; y++) {
            vec2 offset = vec2(x, y) * TEXTURE_PIXEL_SIZE;  // Adjust offset to match texture space
            vec4 neighbor_color = texture(TEXTURE, SCREEN_UV + offset);
            if (neighbor_color.a > threshold) {
                outline = true;
                break;
            }
        }
        if (outline) {
            break;
        }
    }

    if (outline) {
        result = outline_color.rgba;  // Use the outline color's RGB values
    } else {
        discard;
    }
}
          VisualShaderNodeColorParameter             outline_color                              �?         VisualShaderNodeFloatConstant          
�#<          VisualShaderNodeVectorDecompose                                                         VisualShaderNodeVectorCompose             VisualShader          T  shader_type canvas_item;
render_mode blend_mix;

uniform float outline_size : hint_range(0, 64) = 1;
uniform vec4 outline_color : source_color = vec4(0.000000, 0.000000, 0.000000, 1.000000);



void fragment() {
// FloatParameter:2
	float n_out2p0 = outline_size;


// ColorParameter:7
	vec4 n_out7p0 = outline_color;


// FloatConstant:8
	float n_out8p0 = 0.010000;


// Input:5
	vec2 n_out5p0 = SCREEN_UV;


	vec4 n_out6p0;
// Expression:6
	n_out6p0 = vec4(0.0, 0.0, 0.0, 0.0);
	{
		vec4 original_color = texture(TEXTURE, n_out5p0);
		float n_out8p0 = 0.001;
		if (original_color.a > 0.0) {
		    n_out6p0 = original_color.rgba;  // Only return the RGB color channel
		} else {
		    
		    bool outline = false;
		
		    for (float x = -n_out2p0; x <= n_out2p0; x++) {
		        for (float y = -n_out2p0; y <= n_out2p0; y++) {
		            vec2 offset = vec2(x, y) * TEXTURE_PIXEL_SIZE;  // Adjust offset to match texture space
		            vec4 neighbor_color = texture(TEXTURE, n_out5p0 + offset);
		            if (neighbor_color.a > n_out8p0) {
		                outline = true;
		                break;
		            }
		        }
		        if (outline) {
		            break;
		        }
		    }
		
		    if (outline) {
		        n_out6p0 = n_out7p0.rgba;  // Use the outline color's RGB values
		    } else {
		        discard;
		    }
		}
		
	}


// VectorDecompose:9
	float n_out9p0 = n_out6p0.x;
	float n_out9p1 = n_out6p0.y;
	float n_out9p2 = n_out6p0.z;
	float n_out9p3 = n_out6p0.w;


// VectorCompose:10
	vec3 n_out10p0 = vec3(n_out9p0, n_out9p1, n_out9p2);


// Output:0
	COLOR.rgb = n_out10p0;


}
    
   �ė�A                      
     �D  C                 
     4�    !            "   
     9�  D#            $   
     p�    %   
     >D  fD&      @   0,0,outline_size;1,5,outline_color;2,0,threshold;3,3,SCREEN_UV; '         0,5,result; (      C  vec4 original_color = texture(TEXTURE, SCREEN_UV);
float threshold = 0.001;
if (original_color.a > 0.0) {
    result = original_color.rgba;  // Only return the RGB color channel
} else {
    
    bool outline = false;

    for (float x = -outline_size; x <= outline_size; x++) {
        for (float y = -outline_size; y <= outline_size; y++) {
            vec2 offset = vec2(x, y) * TEXTURE_PIXEL_SIZE;  // Adjust offset to match texture space
            vec4 neighbor_color = texture(TEXTURE, SCREEN_UV + offset);
            if (neighbor_color.a > threshold) {
                outline = true;
                break;
            }
        }
        if (outline) {
            break;
        }
    }

    if (outline) {
        result = outline_color.rgba;  // Use the outline color's RGB values
    } else {
        discard;
    }
}
 )            *   
     4�  pC+            ,   
     4�  �C-            .   
     %D  �A/            0   
     pD  �A1       $                                                  	       	       
       	      
      	      
                   
                     RSRC