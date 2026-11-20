class_name LayerParam
extends Resource
## Declarative description of one tunable layer parameter.
##
## [member name] is the shader uniform the value is pushed to. The UI binds to these
## generically, so a layer only has to list its params. Every property emits [signal
## Resource.changed] when assigned, so a [Layer] re-syncs on in-place edits.

enum Type { FLOAT, INT, BOOL, COLOR, ENUM }

const STEP_EPSILON := 0.000001

## Shader uniform name.
@export var name: StringName:
	set(value):
		name = value
		emit_changed()
@export var type: Type = Type.FLOAT:
	set(value):
		type = value
		emit_changed()
## Display text; falls back to [member name] when empty.
@export var label: String:
	set(value):
		label = value
		emit_changed()
@export var min_value := 0.0:
	set(value):
		min_value = value
		emit_changed()
@export var max_value := 1.0:
	set(value):
		max_value = value
		emit_changed()
## Snapping increment for FLOAT/INT; 0 disables snapping.
@export var step := 0.0:
	set(value):
		step = value
		emit_changed()
@export var default_value: Variant:
	set(value):
		default_value = value
		emit_changed()
## Option labels for ENUM; the value is the selected index.
@export var options: PackedStringArray:
	set(value):
		options = value
		emit_changed()


## Returns [param value] coerced to this param's type and constrained to its range.
## A null value falls back to [member default_value], then to a type default (0.0, 0, false,
## Color.WHITE, option 0). A value of the wrong kind also falls back (with a warning):
## FLOAT/INT/ENUM accept only int or float; BOOL accepts bool, int/float (nonzero = true) and
## the strings "true"/"false" (case-insensitive); COLOR accepts a Color or a valid HTML color
## string. FLOAT/INT are clamped to the bounds (swapped if min_value > max_value), snapped to
## the step grid starting at min_value, and never exceed max_value; an off-grid maximum steps
## down to the last grid value. INT uses max(1, round(step)) as its step.
func clamp_value(value: Variant) -> Variant:
	if value == null:
		value = _fallback()
	elif not _is_valid_input(value):
		push_warning("LayerParam '%s': invalid %s value %s" % [name, Type.keys()[type], value])
		value = _fallback()
	match type:
		Type.FLOAT:
			return _clamp_float(_finite_float(value))
		Type.INT:
			return _clamp_int(roundi(value) if value is float else int(value))
		Type.BOOL:
			return _to_bool(value)
		Type.COLOR:
			return _to_color(value)
		Type.ENUM:
			return clampi(int(value), 0, maxi(options.size() - 1, 0))
	return value


func get_display_label() -> String:
	return label if not label.is_empty() else String(name)


## Converts [param value] to a finite float; NaN/INF warn and fall back to the default.
func _finite_float(value: Variant) -> float:
	var number := float(value)
	if is_finite(number):
		return number
	push_warning("LayerParam '%s': non-finite float value" % name)
	var fallback := float(default_value) if default_value is int or default_value is float else 0.0
	return fallback if is_finite(fallback) else 0.0


func _fallback() -> Variant:
	if default_value != null and _is_valid_input(default_value):
		return default_value
	return _type_default()


func _is_valid_input(value: Variant) -> bool:
	match type:
		Type.FLOAT, Type.INT, Type.ENUM:
			return value is int or value is float
		Type.BOOL:
			return value is bool or value is int or value is float or _bool_from_string(value) != 0
		Type.COLOR:
			return value is Color or _color_from_string(value).a >= 0.0
	return true


## Returns 1 for "true", -1 for "false" (case-insensitive), 0 for anything else.
func _bool_from_string(value: Variant) -> int:
	if value is String or value is StringName:
		match String(value).strip_edges().to_lower():
			"true":
				return 1
			"false":
				return -1
	return 0


func _to_bool(value: Variant) -> bool:
	if value is String or value is StringName:
		return _bool_from_string(value) > 0
	return bool(value)


func _color_from_string(value: Variant) -> Color:
	if value is String or value is StringName:
		return Color.from_string(String(value), Color(0.0, 0.0, 0.0, -1.0))
	return Color(0.0, 0.0, 0.0, -1.0)


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
	if step > 0.0:
		var int_step := maxi(1, roundi(step))
		if int_step > 1:
			var steps := roundi(float(clamped - lower_bound) / float(int_step))
			clamped = lower_bound + steps * int_step
			if clamped > upper_bound:
				var max_steps := floori(float(upper_bound - lower_bound) / float(int_step))
				clamped = lower_bound + max_steps * int_step
			clamped = clampi(clamped, lower_bound, upper_bound)
	return clamped


func _to_color(value: Variant) -> Color:
	if value is Color:
		return value
	var default_color: Color = default_value if default_value is Color else Color.WHITE
	var parsed := _color_from_string(value)
	return parsed if parsed.a >= 0.0 else default_color
