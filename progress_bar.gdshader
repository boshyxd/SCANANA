shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform vec4 background_color : source_color = vec4(0.1, 0.1, 0.1, 0.6);
uniform vec4 foreground_color : source_color = vec4(0.0, 0.8, 0.0, 0.8);
uniform float wave_amplitude : hint_range(0.0, 0.1) = 0.02;
uniform float wave_frequency : hint_range(0.0, 10.0) = 3.0;
uniform float wave_speed : hint_range(0.0, 5.0) = 1.5;
uniform float glow_intensity : hint_range(0.0, 1.0) = 0.5;

uniform float particle_speed : hint_range(0.01, 0.5) = 0.05;
uniform float particle_lifetime : hint_range(1.0, 10.0) = 3.0;
uniform float particle_softness : hint_range(0.001, 1.0) = 0.01;
uniform float particle_spacing : hint_range(0.01, 1.0) = 0.1;
uniform vec2 particle_offset = vec2(0.0, 0.0);
uniform vec2 particle_start_scale = vec2(0.02, 0.02);
uniform vec2 particle_end_scale = vec2(0.01, 0.01);
uniform float particle_scale_randomness : hint_range(0.0, 1.0) = 0.5;
uniform int particle_amount : hint_range(0, 50) = 20;

float rand(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

float particle(vec2 uv, float particle_id, float time) {
    float random_offset = rand(vec2(particle_id, 0.0));
    float spawn_time = particle_id * particle_spacing;
    float life = mod(time - spawn_time, particle_lifetime) / particle_lifetime;
    
    if (life < 0.0 || life >= 1.0) return 0.0;
    
    float vertical_pos = rand(vec2(particle_id, 1.0));
    float horizontal_pos = progress + life * particle_speed;
    
    vec2 particle_pos = vec2(horizontal_pos, vertical_pos) + particle_offset;
    
    float scale_random = rand(vec2(particle_id, 2.0)) * particle_scale_randomness;
    vec2 start_scale = particle_start_scale * (1.0 - scale_random);
    vec2 end_scale = particle_end_scale * (1.0 - scale_random);
    vec2 current_scale = mix(start_scale, end_scale, life);
    
    vec2 scaled_uv = (uv - particle_pos) / current_scale;
    float dist = length(scaled_uv);
    
    float alpha = 1.0 - life;
    
    return smoothstep(1.0 + particle_softness, 1.0, dist) * alpha;
}

void fragment() {
    vec2 uv = UV;
    
    float wave_offset = wave_amplitude * sin(wave_frequency * uv.y + TIME * wave_speed);
    
    float wave_progress = progress + wave_offset;
    
    vec4 final_color = background_color;
    
    if (uv.x < wave_progress) {
        final_color = foreground_color;
        
        float edge_dist = abs(uv.x - wave_progress);
        float glow = smoothstep(0.1, 0.0, edge_dist) * glow_intensity;
        final_color.rgb += glow;
    }
    
    float particles = 0.0;
    for (float i = 0.0; i < float(particle_amount); i++) {
        particles += particle(uv, i, TIME);
    }
    particles = clamp(particles, 0.0, 1.0);
    
    final_color = mix(final_color, foreground_color + vec4(0.2), particles * step(uv.x, 1.0));
    
    COLOR = final_color;
}