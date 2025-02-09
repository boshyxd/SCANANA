shader_type canvas_item;

uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    
    float split_amount = glitch_intensity * 0.02;
    vec4 red_channel = texture(SCREEN_TEXTURE, vec2(uv.x + split_amount, uv.y));
    vec4 blue_channel = texture(SCREEN_TEXTURE, vec2(uv.x - split_amount, uv.y));
    vec4 green_channel = texture(SCREEN_TEXTURE, uv);
    
    float shake = (random(vec2(TIME * 0.1, 0.0)) * 2.0 - 1.0) * glitch_intensity * 0.05;
    uv.y += shake;
    
    float line_noise = step(0.98 - (glitch_intensity * 0.3), random(vec2(TIME * 0.1, floor(uv.y * 20.0))));
    vec2 line_offset = vec2(line_noise * 0.02 * (random(vec2(TIME)) * 2.0 - 1.0), 0.0);
    uv += line_offset;
    
    float scanline = sin(uv.y * 400.0) * 0.4 * glitch_intensity;
    
    vec4 color;
    color.r = red_channel.r;
    color.g = green_channel.g;
    color.b = blue_channel.b;
    color.a = 1.0;
    
    color.rgb += vec3(scanline);
    color.rgb += vec3(random(uv + vec2(TIME * 0.001))) * glitch_intensity * 0.1;
    
    float band = step(0.99 - (glitch_intensity * 0.3), random(vec2(TIME * 0.1, floor(uv.y * 5.0))));
    if (band > 0.0) {
        color.rgb = mix(color.rgb, vec3(1.0), 0.1 * glitch_intensity);
    }
    
    COLOR = color;
}