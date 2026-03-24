shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// --- Outline Settings ---
uniform bool outline_enabled = true;
uniform float outline_thickness = 1.0;
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float edge_threshold = 0.15;

// --- Visual Polish ---
uniform float vignette_intensity = 0.4;
uniform float vignette_opacity = 0.4;
uniform float saturation = 1.2;
uniform float contrast = 1.1;

void fragment() {
    vec2 uv = SCREEN_UV;
    vec4 screen_color = texture(SCREEN_TEXTURE, uv);
    vec3 color = screen_color.rgb;
    
    // --- Color Grading ---
    if (saturation != 1.0 || contrast != 1.0) {
        // Contrast
        color = mix(vec3(0.5), color, contrast);
        // Saturation
        float luma = dot(color, vec3(0.299, 0.587, 0.114));
        color = mix(vec3(luma), color, saturation);
    }
    
    // --- Vignette ---
    if (vignette_intensity > 0.0) {
        float d = distance(uv, vec2(0.5));
        float v = smoothstep(0.8, 1.0 - vignette_intensity, d);
        color = mix(color, color * v, vignette_opacity);
    }
    
    COLOR = vec4(color, 1.0);
}
