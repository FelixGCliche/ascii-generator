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
	assert_almost_eq(param.clamp_value(2.0), 0.85, 0.0001)


func test_int_clamps_and_snaps() -> void:
	var param := _make(LayerParam.Type.INT, 2.0, 20.0, 4.0)
	assert_eq(param.clamp_value(100), 18)
	assert_eq(param.clamp_value(-5), 2)
	assert_eq(param.clamp_value(7), 6)
	assert_typeof(param.clamp_value(7.9), TYPE_INT)


func test_enum_clamps_to_option_index() -> void:
	var param := _make(LayerParam.Type.ENUM)
	param.options = PackedStringArray(["a", "b", "c"])
	assert_eq(param.clamp_value(1), 1)
	assert_eq(param.clamp_value(9), 2)
	assert_eq(param.clamp_value(-1), 0)


func test_bool_coerces() -> void:
	assert_eq(_make(LayerParam.Type.BOOL).clamp_value(true), true)
	assert_eq(_make(LayerParam.Type.BOOL).clamp_value(false), false)
	assert_eq(_make(LayerParam.Type.BOOL).clamp_value(1), true)
	assert_eq(_make(LayerParam.Type.BOOL).clamp_value(0), false)


func test_color_validates() -> void:
	var param := _make(LayerParam.Type.COLOR)
	assert_eq(param.clamp_value(Color(2, 0.5, 0)), Color(2, 0.5, 0))
	assert_eq(param.clamp_value("#ff0000"), Color.RED)
	assert_eq(param.clamp_value(12), Color.WHITE)
	param.default_value = Color.BLUE
	assert_eq(param.clamp_value("nonsense"), Color.BLUE)


func test_null_default_gets_type_default() -> void:
	assert_eq(_make(LayerParam.Type.FLOAT).clamp_value(null), 0.0)
	assert_eq(_make(LayerParam.Type.INT).clamp_value(null), 0)
	assert_eq(_make(LayerParam.Type.BOOL).clamp_value(null), false)
	assert_eq(_make(LayerParam.Type.COLOR).clamp_value(null), Color.WHITE)
	var param := _make(LayerParam.Type.ENUM)
	param.options = PackedStringArray(["a", "b"])
	assert_eq(param.clamp_value(null), 0)
	param = _make(LayerParam.Type.FLOAT, 0.0, 1.0)
	param.default_value = 0.7
	assert_almost_eq(param.clamp_value(null), 0.7, 0.0001)


func test_inverted_bounds_are_swapped() -> void:
	var param := _make(LayerParam.Type.FLOAT, 5.0, 1.0)
	assert_almost_eq(param.clamp_value(3.0), 3.0, 0.0001)
	assert_almost_eq(param.clamp_value(9.0), 5.0, 0.0001)
	assert_almost_eq(param.clamp_value(-9.0), 1.0, 0.0001)
	param = _make(LayerParam.Type.INT, 10.0, 2.0)
	assert_eq(param.clamp_value(50), 10)
	assert_eq(param.clamp_value(0), 2)


func test_step_never_exceeds_max_and_stays_on_grid() -> void:
	var param := _make(LayerParam.Type.FLOAT, 0.0, 1.0, 0.3)
	assert_almost_eq(param.clamp_value(1.0), 0.9, 0.0001)
	assert_almost_eq(param.clamp_value(0.7), 0.6, 0.0001)
	param = _make(LayerParam.Type.INT, 0.0, 10.0, 4.0)
	assert_eq(param.clamp_value(10), 8)
	assert_eq(param.clamp_value(7), 8)


func test_float_rejects_non_finite() -> void:
	var param := _make(LayerParam.Type.FLOAT, 0.0, 10.0)
	param.default_value = 3.0
	assert_almost_eq(param.clamp_value(NAN), 3.0, 0.0001)
	assert_almost_eq(param.clamp_value(INF), 3.0, 0.0001)
	assert_almost_eq(param.clamp_value(-INF), 3.0, 0.0001)
	param.default_value = null
	assert_almost_eq(param.clamp_value(NAN), 0.0, 0.0001)


func test_int_rounds_floats() -> void:
	var param := _make(LayerParam.Type.INT, 0.0, 10.0)
	assert_eq(param.clamp_value(2.6), 3)
	assert_eq(param.clamp_value(2.4), 2)
	assert_eq(param.clamp_value(-0.6), 0)


func test_float_int_reject_wrong_types() -> void:
	var param := _make(LayerParam.Type.FLOAT, 0.0, 10.0)
	param.default_value = 4.0
	for bad: Variant in [Color.RED, Vector2.ONE, "3.0", true, [1]]:
		assert_almost_eq(param.clamp_value(bad), 4.0, 0.0001)
	assert_almost_eq(param.clamp_value(3), 3.0, 0.0001)
	var int_param := _make(LayerParam.Type.INT, 0.0, 10.0)
	assert_eq(int_param.clamp_value("7"), 0)
	int_param.default_value = 5
	assert_eq(int_param.clamp_value(Vector2.ONE), 5)
	assert_eq(int_param.clamp_value(8.6), 9)


func test_invalid_default_falls_back_to_type_default() -> void:
	var param := _make(LayerParam.Type.FLOAT, 0.0, 10.0)
	param.default_value = "oops"
	assert_almost_eq(param.clamp_value(Color.RED), 0.0, 0.0001)


func test_bool_accepts_numbers_and_strings() -> void:
	var param := _make(LayerParam.Type.BOOL)
	assert_eq(param.clamp_value(true), true)
	assert_eq(param.clamp_value(0), false)
	assert_eq(param.clamp_value(2), true)
	assert_eq(param.clamp_value(0.0), false)
	assert_eq(param.clamp_value("TRUE"), true)
	assert_eq(param.clamp_value("False"), false)
	param.default_value = true
	assert_eq(param.clamp_value("maybe"), true)
	assert_eq(param.clamp_value(Color.RED), true)
	param.default_value = false
	assert_eq(param.clamp_value(Vector2.ONE), false)


func test_color_invalid_falls_back() -> void:
	var param := _make(LayerParam.Type.COLOR)
	param.default_value = Color.GREEN
	assert_eq(param.clamp_value("not a color"), Color.GREEN)
	assert_eq(param.clamp_value(5), Color.GREEN)
	assert_eq(param.clamp_value("#ff0000"), Color.RED)
	assert_eq(param.clamp_value(Color.BLUE), Color.BLUE)


func test_enum_rejects_wrong_types() -> void:
	var param := _make(LayerParam.Type.ENUM)
	param.options = PackedStringArray(["a", "b", "c"])
	param.default_value = 1
	assert_eq(param.clamp_value("b"), 1)
	assert_eq(param.clamp_value(2.0), 2)


func test_int_fractional_step_rounds_to_whole() -> void:
	var param := _make(LayerParam.Type.INT, 0.0, 10.0, 0.4)
	assert_eq(param.clamp_value(7), 7)
	param.step = 2.6
	assert_eq(param.clamp_value(4), 3)
	assert_eq(param.clamp_value(10), 9)
	param.step = 0.0
	assert_eq(param.clamp_value(7), 7)


func test_int_step_never_exceeds_max() -> void:
	var param := _make(LayerParam.Type.INT, 1.0, 10.0, 4.0)
	assert_eq(param.clamp_value(10), 9)
	assert_eq(param.clamp_value(8), 9)
	assert_eq(param.clamp_value(6), 5)
