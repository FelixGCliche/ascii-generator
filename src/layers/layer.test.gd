extends GutTest

const TEST_SHADER_CODE := """
shader_type canvas_item;
uniform sampler2D input_tex;
uniform float strength = 0.0;
uniform int mode = 0;
uniform bool invert = false;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	COLOR = texture(input_tex, UV) * tint * strength;
}
"""

var _layer: Layer


func before_each() -> void:
	var shader := Shader.new()
	shader.code = TEST_SHADER_CODE
	var mode := _param(&"mode", LayerParam.Type.ENUM, 1)
	mode.options = PackedStringArray(["a", "b", "c"])
	_layer = Layer.new()
	_layer.shader = shader
	_layer.params = [
		_param(&"strength", LayerParam.Type.FLOAT, 0.5, 0.0, 1.0),
		mode,
		_param(&"invert", LayerParam.Type.BOOL, true),
		_param(&"tint", LayerParam.Type.COLOR, Color.RED),
	]
	add_child_autofree(_layer)


func _param(
	param_name: StringName, type: LayerParam.Type, default_value: Variant, lo := 0.0, hi := 1.0
) -> LayerParam:
	var param := LayerParam.new()
	param.name = param_name
	param.type = type
	param.default_value = default_value
	param.min_value = lo
	param.max_value = hi
	return param


func _uniform(param_name: StringName) -> Variant:
	return _layer.get_layer_material().get_shader_parameter(param_name)


func test_params_apply_defaults_to_uniforms() -> void:
	assert_almost_eq(_uniform(&"strength"), 0.5, 0.0001)
	assert_eq(_uniform(&"mode"), 1)
	assert_eq(_uniform(&"invert"), true)
	assert_eq(_uniform(&"tint"), Color.RED)
	assert_almost_eq(_layer.get_param(&"strength"), 0.5, 0.0001)


func test_set_param_clamps_and_emits() -> void:
	watch_signals(_layer)
	_layer.set_param(&"strength", 3.0)
	assert_almost_eq(_layer.get_param(&"strength"), 1.0, 0.0001)
	assert_almost_eq(_uniform(&"strength"), 1.0, 0.0001)
	assert_signal_emitted_with_parameters(_layer, "param_changed", [&"strength", 1.0])
	_layer.set_param(&"mode", 7)
	assert_eq(_uniform(&"mode"), 2)


func test_unknown_param_is_ignored() -> void:
	watch_signals(_layer)
	_layer.set_param(&"nope", 1.0)
	assert_signal_not_emitted(_layer, "param_changed")
	assert_null(_layer.get_param(&"nope"))
	assert_null(_uniform(&"nope"))
	_layer.reset_param(&"nope")
	assert_signal_not_emitted(_layer, "param_changed")


func test_reset_param_restores_default() -> void:
	_layer.set_param(&"strength", 0.9)
	_layer.set_param(&"mode", 0)
	_layer.reset_param(&"strength")
	assert_almost_eq(_uniform(&"strength"), 0.5, 0.0001)
	assert_eq(_uniform(&"mode"), 0)


func test_reset_all_restores_defaults() -> void:
	_layer.set_param(&"strength", 0.9)
	_layer.set_param(&"invert", false)
	_layer.set_param(&"tint", Color.BLUE)
	_layer.reset_all()
	assert_almost_eq(_uniform(&"strength"), 0.5, 0.0001)
	assert_eq(_uniform(&"invert"), true)
	assert_eq(_uniform(&"tint"), Color.RED)


func test_enabled_swaps_material() -> void:
	assert_eq(_layer.get_active_material(), _layer.get_layer_material())
	_layer.enabled = false
	assert_eq(_layer.get_active_material(), _layer.get_passthrough_material())
	assert_eq(_layer.get_passthrough_material().shader, Layer.PASSTHROUGH_SHADER)
	_layer.enabled = true
	assert_eq(_layer.get_active_material(), _layer.get_layer_material())


func test_input_tex_propagates_and_resizes() -> void:
	var tex := ImageTexture.create_from_image(Image.create(64, 32, false, Image.FORMAT_RGBA8))
	_layer.input_tex = tex
	assert_eq(_layer.get_layer_material().get_shader_parameter(&"input_tex"), tex)
	assert_eq(_layer.get_passthrough_material().get_shader_parameter(&"input_tex"), tex)
	assert_eq(_layer.size, Vector2i(64, 32))


func test_works_outside_scene_tree() -> void:
	var layer := Layer.new()
	layer.params = [_param(&"strength", LayerParam.Type.FLOAT, 0.25)]
	layer.set_param(&"strength", 0.75)
	assert_almost_eq(layer.get_param(&"strength"), 0.75, 0.0001)
	layer.enabled = false
	assert_eq(layer.get_active_material(), layer.get_passthrough_material())
	layer.free()


func test_get_output_is_viewport_texture() -> void:
	assert_eq(_layer.get_output(), _layer.get_texture())
