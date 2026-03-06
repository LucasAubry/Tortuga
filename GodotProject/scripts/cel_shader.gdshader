shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_test_disabled, depth_draw_never;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;

uniform float line_thickness = 1.0;
uniform vec3 outline_color : source_color = vec3(0.01, 0.01, 0.02);
uniform float depth_threshold = 1.5; // Linear depth diff in meters
uniform float normal_threshold = 0.3; // Normal vector distance

void vertex() {
	// Snap vertex to fullscreen quad coordinates
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float get_linear_depth(vec2 uv, mat4 inv_proj, sampler2D depth_sampler) {
	float d = texture(depth_sampler, uv).x;
	vec3 ndc = vec3(uv * 2.0 - 1.0, d);
	vec4 view = inv_proj * vec4(ndc, 1.0);
	view.xyz /= view.w;
	return -view.z;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 offset = vec2(line_thickness) / VIEWPORT_SIZE;
	
	// Normal Edge Detection
	vec3 n = texture(normal_tex, uv).xyz * 2.0 - 1.0;
	vec3 n1 = texture(normal_tex, uv + vec2(offset.x, 0.0)).xyz * 2.0 - 1.0;
	vec3 n2 = texture(normal_tex, uv - vec2(offset.x, 0.0)).xyz * 2.0 - 1.0;
	vec3 n3 = texture(normal_tex, uv + vec2(0.0, offset.y)).xyz * 2.0 - 1.0;
	vec3 n4 = texture(normal_tex, uv - vec2(0.0, offset.y)).xyz * 2.0 - 1.0;
	
	float n_diff = distance(n, n1) + distance(n, n2) + distance(n, n3) + distance(n, n4);
	
	// Linear Depth Edge Detection
	float d = get_linear_depth(uv, INV_PROJECTION_MATRIX, depth_tex);
	float d1 = get_linear_depth(uv + vec2(offset.x, 0.0), INV_PROJECTION_MATRIX, depth_tex);
	float d2 = get_linear_depth(uv - vec2(offset.x, 0.0), INV_PROJECTION_MATRIX, depth_tex);
	float d3 = get_linear_depth(uv + vec2(0.0, offset.y), INV_PROJECTION_MATRIX, depth_tex);
	float d4 = get_linear_depth(uv - vec2(0.0, offset.y), INV_PROJECTION_MATRIX, depth_tex);
	
	float d_diff = abs(d1 - d) + abs(d2 - d) + abs(d3 - d) + abs(d4 - d);
	
	// Background mask logic (don't draw aggressive sky outlines usually, or if depth is extremely far)
	bool is_edge = (n_diff > normal_threshold) || (d_diff > depth_threshold * (1.0 + d * 0.01)); // Scale threshold by distance
	
	if (is_edge && d < 900.0) { // Don't outline the skybox
		ALBEDO = outline_color;
		ALPHA = 0.9; // Draw the black line
	} else {
		ALPHA = 0.0; // Let the game render normally underneath
	}
}
