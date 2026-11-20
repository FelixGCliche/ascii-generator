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


class SizedTexture:
	extends Texture2D
	var w := 8
	var h := 8

	func _get_width() -> int:
		return w

	func _get_height() -> int:
		return h


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


func test_enabled_swaps_shader() -> void:
	var own_shader := _layer.shader
	assert_eq(_layer.get_layer_material().shader, own_shader)
	_layer.enabled = false
	assert_eq(_layer.get_layer_material().shader, Layer.PASSTHROUGH_SHADER)
	_layer.enabled = true
	assert_eq(_layer.get_layer_material().shader, own_shader)


func test_values_persist_across_shader_swaps() -> void:
	var tex := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	_layer.input_tex = tex
	_layer.set_param(&"strength", 0.9)
	_layer.enabled = false
	assert_eq(_layer.get_layer_material().get_shader_parameter(&"input_tex"), tex)
	_layer.enabled = true
	assert_eq(_layer.get_layer_material().get_shader_parameter(&"input_tex"), tex)
	assert_almost_eq(_uniform(&"strength"), 0.9, 0.0001)
	var own_shader := _layer.shader
	_layer.shader = null
	_layer.shader = own_shader
	assert_eq(_layer.get_layer_material().get_shader_parameter(&"input_tex"), tex)
	assert_almost_eq(_uniform(&"strength"), 0.9, 0.0001)


func test_input_tex_propagates_and_resizes() -> void:
	var tex := ImageTexture.create_from_image(Image.create(64, 32, false, Image.FORMAT_RGBA8))
	_layer.input_tex = tex
	assert_eq(_layer.get_layer_material().get_shader_parameter(&"input_tex"), tex)
	assert_eq(_layer.size, Vector2i(64, 32))


func test_works_outside_scene_tree() -> void:
	var layer := Layer.new()
	layer.params = [_param(&"strength", LayerParam.Type.FLOAT, 0.25)]
	layer.set_param(&"strength", 0.75)
	assert_almost_eq(layer.get_param(&"strength"), 0.75, 0.0001)
	layer.enabled = false
	assert_eq(layer.get_layer_material().shader, Layer.PASSTHROUGH_SHADER)
	layer.free()


func test_get_output_is_viewport_texture() -> void:
	assert_eq(_layer.get_output(), _layer.get_texture())


func test_zero_size_texture_keeps_previous_size() -> void:
	_layer.input_tex = ImageTexture.create_from_image(
		Image.create(64, 32, false, Image.FORMAT_RGBA8)
	)
	_layer.input_tex = ImageTexture.new()
	assert_eq(_layer.size, Vector2i(64, 32))
	_layer.input_tex = null
	assert_eq(_layer.size, Vector2i(64, 32))


func test_refresh_size_and_changed_signal() -> void:
	var tex := SizedTexture.new()
	_layer.input_tex = tex
	assert_eq(_layer.size, Vector2i(8, 8))
	tex.w = 20
	_layer.refresh_size()
	assert_eq(_layer.size, Vector2i(20, 8))
	tex.h = 30
	tex.emit_changed()
	assert_eq(_layer.size, Vector2i(20, 30))
	tex.w = 0
	_layer.refresh_size()
	assert_eq(_layer.size, Vector2i(20, 30))
	_layer.input_tex = null
	assert_eq(tex.changed.get_connections().size(), 0)


func test_updates_once_and_retriggers() -> void:
	assert_eq(_layer.render_target_update_mode, SubViewport.UPDATE_ONCE)
	var triggers := {
		"param": func() -> void: _layer.set_param(&"strength", 0.9),
		"enabled": func() -> void: _layer.enabled = false,
		"shader": func() -> void: _layer.shader = null,
		"input": func() -> void: _layer.input_tex = SizedTexture.new(),
		"params": func() -> void: _layer.params = [],
		"sync": func() -> void: _layer.sync_params(),
		"request": func() -> void: _layer.request_update(),
	}
	for key in triggers:
		_layer.render_target_update_mode = SubViewport.UPDATE_DISABLED
		triggers[key].call()
		assert_eq(_layer.render_target_update_mode, SubViewport.UPDATE_ONCE, key)


func test_dropped_params_clear_uniforms() -> void:
	_layer.params = [_param(&"strength", LayerParam.Type.FLOAT, 0.5)]
	assert_null(_uniform(&"mode"))
	assert_null(_uniform(&"tint"))
	assert_almost_eq(_uniform(&"strength"), 0.5, 0.0001)


func test_set_param_emits_only_on_change() -> void:
	watch_signals(_layer)
	_layer.set_param(&"strength", 0.5)
	assert_signal_not_emitted(_layer, "param_changed")
	_layer.set_param(&"strength", 0.6)
	assert_signal_emit_count(_layer, "param_changed", 1)
	_layer.set_param(&"strength", 0.6)
	_layer.set_param(&"strength", 5.0)
	_layer.set_param(&"strength", 1.0)
	assert_signal_emit_count(_layer, "param_changed", 2)


func test_reset_all_emits_only_changed() -> void:
	_layer.set_param(&"strength", 0.9)
	_layer.set_param(&"invert", false)
	watch_signals(_layer)
	_layer.reset_all()
	assert_signal_emit_count(_layer, "param_changed", 2)


func test_null_shader_falls_back_to_passthrough() -> void:
	_layer.shader = null
	assert_eq(_layer.get_layer_material().shader, Layer.PASSTHROUGH_SHADER)


func test_request_update_emits_output_changed() -> void:
	watch_signals(_layer)
	_layer.request_update()
	assert_signal_emit_count(_layer, "output_changed", 1)
	_layer.set_param(&"strength", 0.9)
	assert_signal_emit_count(_layer, "output_changed", 2)


func test_scene_assigned_params_apply_without_ready() -> void:
	var source := Layer.new()
	source.params = [_param(&"strength", LayerParam.Type.FLOAT, 0.25)]
	var scene := PackedScene.new()
	scene.pack(source)
	source.free()
	var layer: Layer = scene.instantiate()
	assert_almost_eq(layer.get_param(&"strength"), 0.25, 0.0001)
	assert_almost_eq(layer.get_layer_material().get_shader_parameter(&"strength"), 0.25, 0.0001)
	layer.free()
