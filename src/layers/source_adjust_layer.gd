class_name SourceAdjustLayer
extends Layer
## Source adjustment pass: exposure, contrast and saturation.

const SHADER := preload("res://src/shaders/source_adjust.gdshader")


func _init() -> void:
	super()
	name = &"Source Adjust"
	shader = SHADER
	params = [
		_float_param(&"exposure", "Exposure", -3.0, 3.0, 0.0),
		_float_param(&"contrast", "Contrast", 0.0, 3.0, 1.0),
		_float_param(&"saturation", "Saturation", 0.0, 3.0, 1.0),
	]


static func _float_param(
	param_name: StringName, label: String, min_value: float, max_value: float, default: float
) -> LayerParam:
	var param := LayerParam.new()
	param.name = param_name
	param.type = LayerParam.Type.FLOAT
	param.label = label
	param.min_value = min_value
	param.max_value = max_value
	param.step = 0.01
	param.default_value = default
	return param
