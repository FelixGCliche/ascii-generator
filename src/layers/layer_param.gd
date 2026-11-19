class_name LayerParam
extends Resource
## Declarative description of one tunable layer parameter.
##
## [member name] is the shader uniform the value is pushed to. The UI binds to these
## generically, so a layer only has to list its params.

enum Type { FLOAT, INT, BOOL, COLOR, ENUM }

const STEP_EPSILON := 0.000001

## Shader uniform name.
@export var name: StringName
@export var type: Type = Type.FLOAT
## Display text; falls back to [member name] when empty.
@export var label: String
@export var min_value := 0.0
@export var max_value := 1.0
## Snapping increment for FLOAT/INT; 0 disables snapping.
@export var step := 0.0
@export var default_value: Variant
## Option labels for ENUM; the value is the selected index.
@export var options: PackedStringArray


## Returns [param value] coerced to this param's type and constrained to its range.
## A null value falls back to [member default_value], then to a type default (0.0, 0, false,
## Color.WHITE, option 0). BOOL goes through bool(); COLOR accepts a Color or a valid HTML color
## string, anything else falls back to the default (or Color.WHITE). FLOAT/INT are clamped to the
## bounds (swapped if min_value > max_value), snapped to the step grid starting at min_value, and
## never exceed max_value; an off-grid maximum steps down to the last grid value.
func clamp_value(value: Variant) -> Variant:
	if value == null:
		value = default_value if default_value != null else _type_default()
	match type:
		Type.FLOAT:
			return _clamp_float(float(value))
		Type.INT:
			return _clamp_int(int(value))
		Type.BOOL:
			return bool(value)
		Type.COLOR:
			return _to_color(value)
		Type.ENUM:
			return clampi(int(value), 0, maxi(options.size() - 1, 0))
	return value


func get_display_label() -> String:
	return label if not label.is_empty() else String(name)


func _type_default() -> Variant:
	match type:
		Type.FLOAT:
			return 0.0
		Type.BOOL:
			return false
		Type.COLOR:
			return Color.WHITE
	return 0


func _clamp_float(value: float) -> float:
	var lower_bound := minf(min_value, max_value)
	var upper_bound := maxf(min_value, max_value)
	var clamped := clampf(value, lower_bound, upper_bound)
	if step > 0.0:
		clamped = lower_bound + snappedf(clamped - lower_bound, step)
		if clamped > upper_bound:
			var step_count := floorf((upper_bound - lower_bound) / step + STEP_EPSILON)
			clamped = lower_bound + step_count * step
		clamped = clampf(clamped, lower_bound, upper_bound)
	return clamped


func _clamp_int(value: int) -> int:
	var lower_bound := ceili(minf(min_value, max_value))
	var upper_bound := floori(maxf(min_value, max_value))
	var clamped := clampi(value, lower_bound, upper_bound)
	var int_step := int(step)
	if int_step > 1:
		clamped = lower_bound + roundi(float(clamped - lower_bound) / int_step) * int_step
		if clamped > upper_bound:
			clamped = lower_bound + ((upper_bound - lower_bound) / int_step) * int_step
		clamped = clampi(clamped, lower_bound, upper_bound)
	return clamped


func _to_color(value: Variant) -> Color:
	if value is Color:
		return value
	var default_color: Color = default_value if default_value is Color else Color.WHITE
	if value is String or value is StringName:
		return Color.from_string(String(value), default_color)
	return default_color
