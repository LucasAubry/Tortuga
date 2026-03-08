shader_type spatial;
render_mode cull_front, unshaded;

uniform vec4 outline_color : source_color = vec4(0, 0, 0, 1);
uniform float outline_thickness = 0.02;

void vertex() {
	// Cette méthode est plus robuste pour les objets à grande échelle
	// On déplace les sommets le long de leurs normales dans l'espace local
	VERTEX += NORMAL * outline_thickness;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
