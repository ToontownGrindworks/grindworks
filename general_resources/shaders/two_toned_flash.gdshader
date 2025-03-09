shader_type spatial;
render_mode cull_disabled, depth_test_disabled;

uniform vec4 top_color : source_color;
uniform vec4 bottom_color : source_color;

void fragment() {
    if (NORMAL.y > 0.0) {
        ALBEDO = top_color.rgb;
		ALPHA = (sin(TIME * 2.0) + 1.0) * (0.5 * 0.2);
    } else {
        ALBEDO = bottom_color.rgb;
		ALPHA = (sin(TIME * 2.0) + 1.0) * (0.5 * 0.2);
    }
}
