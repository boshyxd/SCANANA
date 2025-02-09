shader_type spatial;
render_mode unshaded;

uniform sampler2D scan_buffer : filter_nearest;
uniform float scan_radius = 30.0;

void vertex() {
    VERTEX = VERTEX;
}

void fragment() {
    ALBEDO = COLOR.rgb;
    ALPHA = COLOR.a;
} 