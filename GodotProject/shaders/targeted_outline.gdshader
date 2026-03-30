shader_type spatial;
render_mode cull_front, unshaded, blend_mix;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_thickness = 0.5;

void vertex() {
	// Expand the mesh along its normals to create the outline shell
	VERTEX += NORMAL * outline_thickness;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
