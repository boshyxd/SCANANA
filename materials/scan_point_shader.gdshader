shader_type spatial;
render_mode unshaded;

uniform sampler2D scan_buffer : filter_nearest;
uniform float scan_radius = 30.0;

void vertex() {
    // Get particle ID from instance index
    uint id = uint(INSTANCE_ID);
    
    // Calculate texture coordinates
    vec2 tex_pos = vec2(
        float(id % 16u) / 16.0,
        float(id / 16u) / 16.0
    );
    
    // Read position from texture
    vec4 pos_data = texture(scan_buffer, tex_pos);
    
    // Convert color back to position
    vec3 position = (pos_data.rgb * 2.0 - 1.0) * scan_radius;
    
    // Set vertex position
    VERTEX = position;
}

void fragment() {
    ALBEDO = vec3(1.0, 0.0, 0.0);  // Red color
    ALPHA = 1.0;
} 