shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D input_tex;
uniform float exposure : hint_range(-3.0, 3.0, 0.01) = 0.0;
uniform float contrast : hint_range(0.0, 3.0, 0.01) = 1.0;
uniform float saturation : hint_range(0.0, 3.0, 0.01) = 1.0;

void fragment() {
	// TODO(T08): exposure -> contrast -> saturation -> clamp
	COLOR = vec4(texture(input_tex, UV).rgb, 1.0);
}
