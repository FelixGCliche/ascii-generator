shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D input_tex;
uniform float exposure : hint_range(-3.0, 3.0, 1) = 0.0;
uniform float contrast : hint_range(0.0, 3.0, 0.01) = 1.0;
uniform float saturation : hint_range(0.0, 3.0, 0.01) = 1.0;
uniform vec3 luma_weights = vec3(0.299, 0.587, 0.114);

vec4 apply_exposure(vec4 _color, float _exposure) {
  return vec4(_color.rgb * pow(2.0, _exposure), _color.a);
}

vec4 apply_contrast(vec4 _color, float _contrast) {
  return vec4(((_color - 0.5) * _contrast + 0.5));
}

vec4 apply_saturation(vec4 _color, float _saturation) {
  float luma = dot(_color.rgb, luma_weights);
  return vec4(mix(vec3(luma), _color.rgb, _saturation), _color.a);
}

void fragment() {
  vec4 output_tex = texture(input_tex, UV);
  output_tex = apply_exposure(output_tex, exposure);
  output_tex = apply_contrast(output_tex, contrast);
  output_tex = apply_saturation(output_tex, saturation);
  
  COLOR = clamp(output_tex, 0.0, 1.0);
}
