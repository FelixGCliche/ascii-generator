extends GutTest

const EXPECTED := [
	{"name": &"exposure", "min": -3.0, "max": 3.0, "default": 0.0},
	{"name": &"contrast", "min": 0.0, "max": 3.0, "default": 1.0},
	{"name": &"saturation", "min": 0.0, "max": 3.0, "default": 1.0},
]

var _layer: SourceAdjustLayer


func before_each() -> void:
	_layer = autofree(SourceAdjustLayer.new())


func test_layer_name_and_shader() -> void:
	assert_eq(_layer.name, &"SourceAdjust")
	assert_not_null(_layer.shader)


func test_param_definitions() -> void:
	assert_eq(_layer.params.size(), EXPECTED.size())
	for i in EXPECTED.size():
		var param := _layer.params[i]
		var expected: Dictionary = EXPECTED[i]
		assert_eq(param.name, expected["name"])
		assert_eq(param.type, LayerParam.Type.FLOAT)
		assert_almost_eq(param.min_value, expected["min"], 0.0001)
		assert_almost_eq(param.max_value, expected["max"], 0.0001)
		assert_almost_eq(param.step, 0.01, 0.0001)
		assert_almost_eq(float(param.default_value), expected["default"], 0.0001)
		assert_false(param.label.is_empty())


func test_get_param_returns_defaults() -> void:
	for expected in EXPECTED:
		assert_almost_eq(float(_layer.get_param(expected["name"])), expected["default"], 0.0001)
