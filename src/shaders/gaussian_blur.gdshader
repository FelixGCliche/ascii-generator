shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D input_tex : filter_linear, repeat_disable;
uniform float sigma : hint_range(0.0, 10.0, 0.05) = 1.0;
uniform int axis : hint_range(0, 1) = 0;

void fragment() {
	// TODO(T09): 1D Gaussian along `axis` (0 = horizontal, 1 = vertical).
	// sigma <= 0 -> return the unblurred pixel; accumulate weights and normalize.
	COLOR = vec4(texture(input_tex, UV).rgb, 1.0);
}
