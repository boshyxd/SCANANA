shader_type spatial;
render_mode unshaded, blend_add;

uniform vec4 base_color : source_color = vec4(1.0, 0.2, 0.0, 1.0);
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float time_offset = 0.0;

float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
    float time = TIME + time_offset;
    float noise = random(VERTEX.xz + vec2(time * 2.0));
    float glitch_x = sin(time * 10.0 + noise * 10.0) * glitch_intensity * 0.2;
    float glitch_y = cos(time * 8.0 + noise * 8.0) * glitch_intensity * 0.2;
    float glitch_z = sin(time * 12.0 + noise * 6.0) * glitch_intensity * 0.2;
    
    VERTEX += vec3(glitch_x, glitch_y, glitch_z);
    
    float scale = 1.0 + sin(time * 5.0) * 0.3 * glitch_intensity;
    VERTEX *= scale;
}

void fragment() {
    float time = TIME + time_offset;
    vec2 uv = UV;
    
    float r_offset = sin(time * 8.0) * 0.1 * glitch_intensity;
    float g_offset = cos(time * 7.0) * 0.1 * glitch_intensity;
    float b_offset = sin(time * 9.0) * 0.1 * glitch_intensity;
    
    vec4 glitch_color;
    glitch_color.r = base_color.r + r_offset;
    glitch_color.g = base_color.g + g_offset;
    glitch_color.b = base_color.b + b_offset;
    glitch_color.a = base_color.a;
    
    float scanline = step(0.5, fract((UV.y + time * 2.0) * 10.0)) * 0.1 * glitch_intensity;
    
    float noise = random(UV + vec2(time)) * glitch_intensity * 0.3;
    
    ALBEDO = glitch_color.rgb + vec3(scanline) + vec3(noise);
    ALPHA = glitch_color.a * (1.0 - length(UV - vec2(0.5)) * 2.0);
    
    EMISSION = ALBEDO * 2.0;
}