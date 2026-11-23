class_name GaussianBlurLayer
extends Layer
## One axis of a separable Gaussian blur. Chain a horizontal and a vertical instance.

enum Axis { HORIZONTAL, VERTICAL }

const SHADER := preload("res://src/shaders/gaussian_blur.gdshader")


func _init(axis: Axis = Axis.HORIZONTAL) -> void:
	super()
	name = &"GaussianBlurH" if axis == Axis.HORIZONTAL else &"GaussianBlurV"
	shader = SHADER
	params = [_sigma_param(), _axis_param(axis)]


static func _sigma_param() -> LayerParam:
	var param := LayerParam.new()
	param.name = &"sigma"
	param.type = LayerParam.Type.FLOAT
	param.label = "Sigma"
	param.min_value = 0.0
	param.max_value = 10.0
	param.step = 0.05
	param.default_value = 1.0
	return param


static func _axis_param(axis: Axis) -> LayerParam:
	var param := LayerParam.new()
	param.name = &"axis"
	param.type = LayerParam.Type.ENUM
	param.label = "Axis"
	param.options = PackedStringArray(["Horizontal", "Vertical"])
	param.default_value = axis
	return param
