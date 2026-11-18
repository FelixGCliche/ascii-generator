extends GutTest


func _make(type: LayerParam.Type, min_value := 0.0, max_value := 1.0, step := 0.0) -> LayerParam:
	var param := LayerParam.new()
	param.type = type
	param.min_value = min_value
	param.max_value = max_value
	param.step = step
	return param


func test_float_clamps_to_range() -> void:
	var param := _make(LayerParam.Type.FLOAT, -1.0, 2.0)
	assert_almost_eq(param.clamp_value(5.0), 2.0, 0.0001)
	assert_almost_eq(param.clamp_value(-3.0), -1.0, 0.0001)
	assert_almost_eq(param.clamp_value(0.37), 0.37, 0.0001)


func test_float_snaps_to_step_from_min() -> void:
	var param := _make(LayerParam.Type.FLOAT, 0.1, 1.0, 0.25)
	assert_almost_eq(param.clamp_value(0.4), 0.35, 0.0001)
	assert_almost_eq(param.clamp_value(0.5), 0.6, 0.0001)
	assert_almost_eq(param.clamp_value(2.0), 1.0, 0.0001)


func test_int_clamps_and_snaps() -> void:
	var param := _make(LayerParam.Type.INT, 2.0, 20.0, 4.0)
	assert_eq(param.clamp_value(100), 20)
	assert_eq(param.clamp_value(-5), 2)
	assert_eq(param.clamp_value(7), 6)
	assert_typeof(param.clamp_value(7.9), TYPE_INT)


func test_enum_clamps_to_option_index() -> void:
	var param := _make(LayerParam.Type.ENUM)
	param.options = PackedStringArray(["a", "b", "c"])
	assert_eq(param.clamp_value(1), 1)
	assert_eq(param.clamp_value(9), 2)
	assert_eq(param.clamp_value(-1), 0)


func test_bool_and_color_pass_through() -> void:
	assert_eq(_make(LayerParam.Type.BOOL).clamp_value(true), true)
	assert_eq(_make(LayerParam.Type.BOOL).clamp_value(false), false)
	assert_eq(_make(LayerParam.Type.COLOR).clamp_value(Color(2, 0.5, 0)), Color(2, 0.5, 0))
