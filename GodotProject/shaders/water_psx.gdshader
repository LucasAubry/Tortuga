shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// PSX Globals
global uniform float psx_snap_distance;

uniform vec3 water_color : source_color = vec3(0.1, 0.45, 0.55);
uniform vec3 deep_water_color : source_color = vec3(0.05, 0.15, 0.25);
uniform float wave_speed : hint_range(0.0, 5.0) = 0.5;
uniform float wave_height : hint_range(0.0, 5.0) = 1.0;

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// Complex waves to look "good"
	float wave1 = sin(v_world_pos.x * 0.05 + TIME * wave_speed) * cos(v_world_pos.z * 0.05 + TIME * wave_speed);
	float wave2 = sin(v_world_pos.x * 0.1 - TIME * wave_speed * 0.5) * sin(v_world_pos.z * 0.1 + TIME * wave_speed * 1.5);
	VERTEX.y += (wave1 + wave2 * 0.5) * wave_height;
	
	// PSX Vertex Jitter (Standard logic from the plugin's .gdshaderinc)
	// We snap directly in View Space as VERTEX is already transformed by MODELVIEW_MATRIX in Godot 4
	if (psx_snap_distance > 0.0) {
		VERTEX = round(VERTEX / psx_snap_distance) * psx_snap_distance;
	}
}

void fragment() {
	ALBEDO = mix(water_color, deep_water_color, 0.4);
	ROUGHNESS = 0.2;
	SPECULAR = 0.6;
	
	// NO VIGNETTE! (Removed as per user request to avoid black bars on edges)
}
