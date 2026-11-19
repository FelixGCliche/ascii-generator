extends GutTest

var _layer: Layer
var _param: LayerParam


func before_each() -> void:
	_param = LayerParam.new()
	_param.name = &"strength"
	_param.type = LayerParam.Type.FLOAT
	_param.default_value = 0.5
	_layer = Layer.new()
	_layer.params = [_param]
	add_child_autofree(_layer)


func test_params_reassign_emits_for_reclamped_values() -> void:
	_layer.set_param(&"strength", 0.9)
	watch_signals(_layer)
	_param.max_value = 0.4
	_layer.params = _layer.params
	assert_signal_emit_count(_layer, "param_changed", 1)
	assert_signal_emitted_with_parameters(_layer, "param_changed", [&"strength", 0.4])


func test_params_reassign_silent_when_unchanged() -> void:
	watch_signals(_layer)
	_layer.params = _layer.params
	assert_signal_not_emitted(_layer, "param_changed")


func test_new_params_do_not_emit() -> void:
	watch_signals(_layer)
	var other := LayerParam.new()
	other.name = &"other"
	other.default_value = 0.2
	_layer.params = [_param, other]
	assert_signal_not_emitted(_layer, "param_changed")
