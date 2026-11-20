extends GutTest

var _stack: LayerStack


func before_each() -> void:
	_stack = LayerStack.new()
	add_child_autofree(_stack)
	_stack.add_layer(_make_layer("Alpha"))
	_stack.add_layer(_make_layer("Beta"))


func _param(
	param_name: String, type: LayerParam.Type, default: Variant, lo := 0.0, hi := 1.0
) -> LayerParam:
	var p := LayerParam.new()
	p.name = param_name
	p.type = type
	p.default_value = default
	p.min_value = lo
	p.max_value = hi
	if type == LayerParam.Type.ENUM:
		p.options = PackedStringArray(["a", "b", "c"])
	return p


func _make_layer(layer_name: String) -> Layer:
	var layer := Layer.new()
	layer.name = layer_name
	var list: Array[LayerParam] = [
		_param("f", LayerParam.Type.FLOAT, 0.5),
		_param("i", LayerParam.Type.INT, 2, 0.0, 10.0),
		_param("b", LayerParam.Type.BOOL, false),
		_param("c", LayerParam.Type.COLOR, Color.WHITE),
		_param("e", LayerParam.Type.ENUM, 0),
	]
	layer.params = list
	return layer


func _roundtrip_dict() -> Dictionary:
	return PresetSerializer.from_json(PresetSerializer.to_json(_stack))


func test_round_trip_restores_values() -> void:
	var a := _stack.get_layer(0)
	a.set_param(&"f", 0.75)
	a.set_param(&"i", 7)
	a.set_param(&"b", true)
	a.set_param(&"c", Color(0.2, 0.4, 0.6, 0.5))
	a.set_param(&"e", 2)
	a.enabled = false
	var data := _roundtrip_dict()
	a.reset_all()
	a.enabled = true
	var report := PresetSerializer.apply(_stack, data)
	assert_eq(a.get_param(&"f"), 0.75)
	assert_eq(a.get_param(&"i"), 7)
	assert_eq(a.get_param(&"b"), true)
	assert_eq(a.get_param(&"e"), 2)
	assert_false(a.enabled)
	assert_eq(report["skipped_layers"], [])
	assert_eq(report["skipped_params"], [])
	assert_eq(report["applied"], 12)


func test_color_round_trips_with_alpha() -> void:
	var a := _stack.get_layer(0)
	var color := Color.from_rgba8(10, 20, 30, 40)
	a.set_param(&"c", color)
	var data := _roundtrip_dict()
	a.reset_all()
	PresetSerializer.apply(_stack, data)
	assert_eq(a.get_param(&"c").to_rgba32(), color.to_rgba32())


func test_to_dict_shape() -> void:
	var data := PresetSerializer.to_dict(_stack)
	assert_eq(data["version"], PresetSerializer.VERSION)
	assert_eq(data["layers"].size(), 2)
	assert_eq(data["layers"][0]["name"], "Alpha")
	assert_true(data["layers"][0]["params"]["c"] is String)


func test_json_ints_coerced_for_float_params() -> void:
	var text := '{"version":1,"layers":[{"name":"Alpha","params":{"f":1,"i":4.0}}]}'
	PresetSerializer.apply(_stack, PresetSerializer.from_json(text))
	var a := _stack.get_layer(0)
	assert_eq(a.get_param(&"f"), 1.0)
	assert_eq(a.get_param(&"i"), 4)
	assert_typeof(a.get_param(&"i"), TYPE_INT)


func test_unknown_layer_and_param_reported() -> void:
	var text := (
		'{"version":1,"layers":[{"name":"Nope","params":{}},'
		+ '{"name":"Beta","params":{"zzz":1,"f":0.9}}]}'
	)
	var report := PresetSerializer.apply(_stack, PresetSerializer.from_json(text))
	assert_eq(report["skipped_layers"], ["Nope"])
	assert_eq(report["skipped_params"], ["Beta.zzz"])
	assert_eq(report["applied"], 1)
	assert_eq(_stack.get_layer(1).get_param(&"f"), 0.9)
	for e in get_errors():
		e.handled = true


func test_missing_keys_keep_current_values() -> void:
	var a := _stack.get_layer(0)
	a.set_param(&"f", 0.3)
	a.enabled = false
	var text := '{"version":1,"layers":[{"name":"Alpha","params":{"i":5}}]}'
	PresetSerializer.apply(_stack, PresetSerializer.from_json(text))
	assert_eq(a.get_param(&"f"), 0.3)
	assert_false(a.enabled)
	assert_eq(a.get_param(&"i"), 5)


func test_wrong_value_types_are_skipped() -> void:
	var text := (
		'{"version":1,"layers":[{"name":"Alpha","enabled":"yes","params":'
		+ '{"f":"x","b":1,"c":"notacolor","e":null}}]}'
	)
	var report := PresetSerializer.apply(_stack, PresetSerializer.from_json(text))
	var a := _stack.get_layer(0)
	assert_true(a.enabled)
	assert_eq(report["applied"], 0)
	assert_eq(report["skipped_params"].size(), 4)
	assert_eq(a.get_param(&"f"), 0.5)


func test_out_of_range_values_are_clamped() -> void:
	var text := '{"version":1,"layers":[{"name":"Alpha","params":{"f":99,"i":-5}}]}'
	PresetSerializer.apply(_stack, PresetSerializer.from_json(text))
	assert_eq(_stack.get_layer(0).get_param(&"f"), 1.0)
	assert_eq(_stack.get_layer(0).get_param(&"i"), 0)


func test_malformed_json_returns_empty() -> void:
	assert_true(PresetSerializer.from_json("{not json").is_empty())
	assert_true(PresetSerializer.from_json("[1,2]").is_empty())
	assert_true(PresetSerializer.from_json('{"version":"1","layers":[]}').is_empty())
	assert_true(PresetSerializer.from_json('{"version":1,"layers":{}}').is_empty())
	assert_true(PresetSerializer.from_json('{"layers":[]}').is_empty())
	for e in get_errors():
		e.handled = true


func test_malformed_entries_do_not_crash() -> void:
	var text := '{"version":1,"layers":[5,{"name":3},{"name":"Alpha","params":[1]}]}'
	var report := PresetSerializer.apply(_stack, PresetSerializer.from_json(text))
	assert_eq(report["skipped_layers"].size(), 2)
	assert_eq(report["applied"], 0)


func test_newer_version_still_applies() -> void:
	var text := '{"version":99,"layers":[{"name":"Alpha","params":{"i":9}}]}'
	var report := PresetSerializer.apply(_stack, PresetSerializer.from_json(text))
	assert_eq(report["applied"], 1)
	assert_eq(_stack.get_layer(0).get_param(&"i"), 9)
	for e in get_errors():
		e.handled = true


func test_apply_empty_dict_is_noop() -> void:
	var report := PresetSerializer.apply(_stack, {})
	assert_eq(report["applied"], 0)
