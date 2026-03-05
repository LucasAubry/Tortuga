shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(0.0, 0.45, 0.75, 0.85);
uniform vec4 albedo2 : source_color = vec4(0.0, 0.25, 0.55, 0.95);
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.02;
uniform float wave_speed : hint_range(0.0, 5.0) = 0.5;
uniform float wave_amplitude : hint_range(0.0, 5.0) = 1.0;
uniform float wave_frequency : hint_range(0.0, 5.0) = 0.1;

void vertex() {
	// Simple sine wave displacement for the water surface
	float time = TIME * wave_speed;
	float wave1 = sin(VERTEX.x * wave_frequency + time) * wave_amplitude;
	float wave2 = cos(VERTEX.z * wave_frequency * 1.5 + time * 1.2) * wave_amplitude * 0.8;
	
	VERTEX.y += wave1 + wave2;
}

void fragment() {
	// Mix color based on height/time to give it a nice gradient
	float time = TIME * wave_speed * 0.5;
	float wave_mask = sin(UV.x * 20.0 + time) * cos(UV.y * 20.0 + time) * 0.5 + 0.5;
	
	// Draw a navigation grid
	float grid_scale = 100.0; // Size of the squares
	vec2 grid_uv = fract(UV * grid_scale);
	float grid_line_thickness = 0.02;
	float grid = step(grid_line_thickness, grid_uv.x) * step(grid_line_thickness, grid_uv.y);
	// Invert to get lines instead of squares
	grid = 1.0 - grid;
	
	vec3 water_color = mix(albedo.rgb, albedo2.rgb, wave_mask);
	vec3 final_color = mix(water_color, vec3(1.0, 1.0, 1.0), grid * 0.2); // 20% opacity white lines
	
	ALBEDO = final_color;
	ALPHA = mix(albedo.a, albedo2.a, wave_mask);
	
	METALLIC = metallic;
	ROUGHNESS = roughness;
}
