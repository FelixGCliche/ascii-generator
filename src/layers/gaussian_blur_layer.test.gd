extends GutTest


func test_horizontal_defaults() -> void:
	var layer: GaussianBlurLayer = autofree(GaussianBlurLayer.new())
	assert_eq(layer.name, &"GaussianBlurH")
	assert_not_null(layer.shader)
	assert_eq(layer.get_param(&"axis"), GaussianBlurLayer.Axis.HORIZONTAL)
	assert_almost_eq(float(layer.get_param(&"sigma")), 1.0, 0.0001)


func test_vertical_axis() -> void:
	var layer: GaussianBlurLayer = autofree(GaussianBlurLayer.new(GaussianBlurLayer.Axis.VERTICAL))
	assert_eq(layer.name, &"GaussianBlurV")
	assert_eq(layer.get_param(&"axis"), GaussianBlurLayer.Axis.VERTICAL)


func test_param_definitions() -> void:
	var layer: GaussianBlurLayer = autofree(GaussianBlurLayer.new())
	var sigma := layer.params[0]
	assert_eq(sigma.type, LayerParam.Type.FLOAT)
	assert_almost_eq(sigma.min_value, 0.0, 0.0001)
	assert_almost_eq(sigma.max_value, 10.0, 0.0001)
	assert_almost_eq(sigma.step, 0.05, 0.0001)
	var axis := layer.params[1]
	assert_eq(axis.type, LayerParam.Type.ENUM)
	assert_eq(axis.options.size(), 2)


func test_sigma_clamped() -> void:
	var layer: GaussianBlurLayer = autofree(GaussianBlurLayer.new())
	layer.set_param(&"sigma", 50.0)
	assert_almost_eq(float(layer.get_param(&"sigma")), 10.0, 0.0001)
