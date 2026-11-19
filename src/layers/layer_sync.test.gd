extends GutTest


class SizedTexture:
	extends Texture2D
	var w := 8

	func _get_width() -> int:
		return w

	func _get_height() -> int:
		return 8


var _layer: Layer


func before_each() -> void:
	var param := LayerParam.new()
	param.name = &"strength"
	param.default_value = 0.5
	_layer = Layer.new()
	_layer.params = [param]
	add_child_autofree(_layer)


func _uniform(param_name: StringName) -> Variant:
	return _layer.get_layer_material().get_shader_parameter(param_name)


func test_refresh_size_requests_update_only_on_change() -> void:
	var tex := SizedTexture.new()
	_layer.input_tex = tex
	watch_signals(_layer)
	_layer.refresh_size()
	assert_signal_not_emitted(_layer, "output_changed")
	tex.w = 30
	_layer.refresh_size()
	assert_signal_emit_count(_layer, "output_changed", 1)
	assert_eq(_layer.size, Vector2i(30, 8))


func test_texture_changed_signal_rerenders_without_resize() -> void:
	var tex := SizedTexture.new()
	_layer.input_tex = tex
	_layer.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tex.emit_changed()
	assert_eq(_layer.render_target_update_mode, SubViewport.UPDATE_ONCE)


func test_param_resource_edit_resyncs() -> void:
	var param: LayerParam = _layer.params[0]
	param.max_value = 1.0
	_layer.set_param(&"strength", 0.8)
	_layer.render_target_update_mode = SubViewport.UPDATE_DISABLED
	param.max_value = 0.6
	assert_almost_eq(_layer.get_param(&"strength"), 0.6, 0.0001)
	assert_almost_eq(_uniform(&"strength"), 0.6, 0.0001)
	assert_eq(_layer.render_target_update_mode, SubViewport.UPDATE_ONCE)
	param.name = &"renamed"
	assert_null(_uniform(&"strength"))
	assert_not_null(_uniform(&"renamed"))


func test_replaced_param_no_longer_watched() -> void:
	var old := LayerParam.new()
	old.name = &"old"
	_layer.params = [old]
	_layer.params = []
	assert_eq(old.changed.get_connections().size(), 0)


func test_in_place_mutation_needs_sync_params() -> void:
	var extra := LayerParam.new()
	extra.name = &"extra"
	extra.default_value = 0.3
	_layer.params.append(extra)
	assert_null(_layer.get_param(&"extra"))
	_layer.sync_params()
	assert_almost_eq(_layer.get_param(&"extra"), 0.3, 0.0001)


func test_input_tex_reassign_after_external_disconnect() -> void:
	var tex := SizedTexture.new()
	_layer.input_tex = tex
	for connection in tex.changed.get_connections():
		tex.changed.disconnect(connection["callable"])
	var other := SizedTexture.new()
	other.w = 5
	_layer.input_tex = other
	assert_eq(_layer.size, Vector2i(5, 8))
	_layer.input_tex = null
	assert_eq(other.changed.get_connections().size(), 0)
