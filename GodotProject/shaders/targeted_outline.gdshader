shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled;

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_thickness : hint_range(0.0, 5.0) = 1.0;
uniform float depth_threshold : hint_range(0.0, 0.1) = 0.002;

void fragment() {
    float depth = texture(DEPTH_TEXTURE, SCREEN_UV).r;
    
    vec2 size = VIEWPORT_SIZE;
    vec2 offset = (outline_thickness / size);
    
    // Sample depth around the current pixel
    float d_up    = texture(DEPTH_TEXTURE, SCREEN_UV + vec2(0.0, offset.y)).r;
    float d_down  = texture(DEPTH_TEXTURE, SCREEN_UV - vec2(0.0, offset.y)).r;
    float d_left  = texture(DEPTH_TEXTURE, SCREEN_UV - vec2(offset.x, 0.0)).r;
    float d_right = texture(DEPTH_TEXTURE, SCREEN_UV + vec2(offset.x, 0.0)).r;
    
    float edge = abs(depth - d_up) + abs(depth - d_down) + abs(depth - d_left) + abs(depth - d_right);
    
    if (edge > depth_threshold) {
        ALBEDO = outline_color.rgb;
        ALPHA = outline_color.a;
    } else {
        ALPHA = 0.0;
    }
}
