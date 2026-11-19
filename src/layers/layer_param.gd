class_name LayerParam
extends Resource
## Declarative description of one tunable layer parameter.
##
## [member name] is the shader uniform the value is pushed to. The UI binds to these
## generically, so a layer only has to list its params.

enum Type { FLOAT, INT, BOOL, COLOR, ENUM }

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
	var result: Variant = value
	match type:
		Type.FLOAT:
			result = _clamp_float(float(value))
		Type.INT:
			result = _clamp_int(int(value))
		Type.BOOL:
			result = bool(value)
		Type.COLOR:
			result = _to_color(value)
		Type.ENUM:
			result = clampi(int(value), 0, maxi(options.size() - 1, 0))
	return result


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
	var lo := minf(min_value, max_value)
	var hi := maxf(min_value, max_value)
	var f := clampf(value, lo, hi)
	if step > 0.0:
		f = lo + snappedf(f - lo, step)
		if f > hi:
			f = lo + floorf((hi - lo) / step + 0.000001) * step
		f = clampf(f, lo, hi)
	return f


func _clamp_int(value: int) -> int:
	var lo := ceili(minf(min_value, max_value))
	var hi := floori(maxf(min_value, max_value))
	var i := clampi(value, lo, hi)
	var int_step := int(step)
	if int_step > 1:
		i = lo + roundi(float(i - lo) / int_step) * int_step
		if i > hi:
			i = lo + ((hi - lo) / int_step) * int_step
		i = clampi(i, lo, hi)
	return i


func _to_color(value: Variant) -> Color:
	if value is Color:
		return value
	if (value is String or value is StringName) and String(value).is_valid_html_color():
		return Color.html(String(value))
	return default_value if default_value is Color else Color.WHITE
