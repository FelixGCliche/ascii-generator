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
func clamp_value(value: Variant) -> Variant:
	match type:
		Type.FLOAT:
			var f := clampf(float(value), min_value, max_value)
			if step > 0.0:
				f = clampf(min_value + snappedf(f - min_value, step), min_value, max_value)
			return f
		Type.INT:
			var lo := ceili(min_value)
			var hi := floori(max_value)
			var i := clampi(int(value), lo, hi)
			var int_step := int(step)
			if int_step > 1:
				i = clampi(lo + snappedi(i - lo, int_step), lo, hi)
			return i
		Type.ENUM:
			return clampi(int(value), 0, maxi(options.size() - 1, 0))
	return value


func get_display_label() -> String:
	return label if not label.is_empty() else String(name)
