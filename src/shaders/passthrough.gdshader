shader_type canvas_item;

uniform sampler2D input_tex;

void fragment() {
	COLOR = texture(input_tex, UV);
}
