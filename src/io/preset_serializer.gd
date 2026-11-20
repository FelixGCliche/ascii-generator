class_name PresetSerializer
extends RefCounted
## Turns the state of a [LayerStack] into a JSON-safe preset and back.
##
## Layers are identified by their node [member Node.name], so layer names must be unique and
## stable: renaming a layer orphans it in saved presets. Params are identified by their
## [member LayerParam.name].
##
## Format: [code]{"version": 1, "layers": [{"name": ..., "enabled": bool, "params": {...}}]}[/code].
## Colors are stored as HTML strings with alpha; everything else as plain JSON values.

const VERSION := 1


## Snapshots [param stack] into a JSON-safe dictionary.
static func to_dict(stack: LayerStack) -> Dictionary:
	var layers: Array = []
	for layer in stack.get_layers():
		var params := {}
		for param in layer.params:
			if param:
				params[String(param.name)] = _encode(layer.get_param(param.name))
		layers.append({"name": String(layer.name), "enabled": layer.enabled, "params": params})
	return {"version": VERSION, "layers": layers}


static func to_json(stack: LayerStack) -> String:
	return JSON.stringify(to_dict(stack), "\t")


## Parses and validates preset text. Returns an empty Dictionary (and warns) when the text is
## not valid JSON or is not a preset-shaped object.
static func from_json(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("Preset: invalid JSON (%s)" % json.get_error_message())
		return {}
	var data: Variant = json.data
	if not data is Dictionary:
		push_warning("Preset: root must be an object")
		return {}
	var version: Variant = data.get("version")
	if not (version is int or version is float):
		push_warning("Preset: missing or invalid version")
		return {}
	if not data.get("layers") is Array:
		push_warning("Preset: missing or invalid layers")
		return {}
	return data


## Applies [param data] to [param stack] on a best-effort basis and returns a report:
## [code]{applied: int, skipped_layers: [names], skipped_params: ["layer.param"]}[/code].
## [code]applied[/code] counts applied param values and enabled flags. Unknown layers and
## params, and values of the wrong kind, are skipped; missing keys keep their current value.
## Values go through [method Layer.set_param], so clamping applies.
static func apply(stack: LayerStack, data: Dictionary) -> Dictionary:
	var report := {"applied": 0, "skipped_layers": [], "skipped_params": []}
	var version: Variant = data.get("version")
	if (version is int or version is float) and version > VERSION:
		push_warning("Preset: version %s is newer than supported %d" % [version, VERSION])
	var entries: Variant = data.get("layers")
	if not entries is Array:
		return report
	var by_name := {}
	for layer in stack.get_layers():
		by_name[String(layer.name)] = layer
	for entry in entries:
		if not entry is Dictionary or not entry.get("name") is String:
			report["skipped_layers"].append("?")
			continue
		var layer_name: String = entry["name"]
		if not by_name.has(layer_name):
			report["skipped_layers"].append(layer_name)
			continue
		_apply_layer(by_name[layer_name], entry, report)
	return report


static func _apply_layer(layer: Layer, entry: Dictionary, report: Dictionary) -> void:
	if entry.get("enabled") is bool:
		layer.enabled = entry["enabled"]
		report["applied"] += 1
	var values: Variant = entry.get("params")
	if not values is Dictionary:
		return
	for key in values:
		var param := _find_param(layer, String(key))
		var value: Variant = _decode(param, values[key]) if param else null
		if param == null or value == null:
			report["skipped_params"].append("%s.%s" % [layer.name, key])
			continue
		layer.set_param(param.name, value)
		report["applied"] += 1


static func _find_param(layer: Layer, param_name: String) -> LayerParam:
	for param in layer.params:
		if param and String(param.name) == param_name:
			return param
	return null


static func _encode(value: Variant) -> Variant:
	if value is Color:
		return value.to_html(true)
	return value


## Coerces a JSON value to the param's type; null means the value is unusable.
static func _decode(param: LayerParam, value: Variant) -> Variant:
	match param.type:
		LayerParam.Type.FLOAT:
			return float(value) if (value is int or value is float) else null
		LayerParam.Type.INT, LayerParam.Type.ENUM:
			return roundi(value) if (value is int or value is float) else null
		LayerParam.Type.BOOL:
			return value if value is bool else null
		LayerParam.Type.COLOR:
			if value is String:
				var color := Color.from_string(value, Color(0.0, 0.0, 0.0, -1.0))
				return color if color.a >= 0.0 else null
	return null
