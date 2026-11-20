class_name Layer
extends SubViewport
## One pass of the ASCII pipeline.
##
## The viewport only re-renders on demand (UPDATE_ONCE): every state change calls
## [method request_update]. Call it manually after changing anything the layer cannot see.
##
## The viewport follows the size of [member input_tex]. It listens to the texture's [signal
## Resource.changed] signal; textures that resize without emitting it (e.g. an upstream
## layer's viewport texture) need a manual [method refresh_size] call.
##
## Renders [member input_tex] through [member shader] onto a full-size ColorRect and exposes
## the result via [method get_output]. Tunable params are declared in [member params] and
## pushed to the shader uniforms of the same name. When disabled, the layer renders a
## passthrough shader instead, so its output equals its input.

signal param_changed(param_name: StringName, value: Variant)
## Emitted whenever the output may have changed (every [method request_update]).
signal output_changed

const PASSTHROUGH_SHADER := preload("res://src/shaders/passthrough.gdshader")
const INPUT_UNIFORM := &"input_tex"

@export var shader: Shader:
	set(value):
		if value == shader:
			return
		shader = value
		_apply_shader()
## Tunable parameters. Each [LayerParam]'s [signal Resource.changed] re-syncs the layer, so
## editing a param in place is picked up. Godot arrays have no change signal: after appending
## or erasing entries in place, reassign [member params] or call [method sync_params].
@export var params: Array[LayerParam] = []:
	set(value):
		params = value
		_watch_params()
		sync_params()
@export var enabled := true:
	set(value):
		if value == enabled:
			return
		enabled = value
		_apply_shader()

var input_tex: Texture2D:
	set(value):
		if value == input_tex:
			return
		_disconnect_input_tex()
		input_tex = value
		_material.set_shader_parameter(INPUT_UNIFORM, value)
		if value:
			value.changed.connect(_on_input_tex_changed)
		refresh_size()
		request_update()

var _material := ShaderMaterial.new()
var _values := {}
var _rect := ColorRect.new()
var _watched_params: Array[LayerParam] = []


func _init() -> void:
	render_target_update_mode = SubViewport.UPDATE_ONCE
	transparent_bg = true
	disable_3d = true
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_rect, false, Node.INTERNAL_MODE_FRONT)
	_rect.material = _material
	_apply_shader()


func set_param(param_name: StringName, value: Variant) -> void:
	var param := _require_param(param_name)
	if not param:
		return
	var clamped: Variant = param.clamp_value(value)
	if _values.has(param_name) and is_same(_values[param_name], clamped):
		return
	_values[param_name] = clamped
	_material.set_shader_parameter(param_name, clamped)
	request_update()
	param_changed.emit(param_name, clamped)


func get_param(param_name: StringName) -> Variant:
	if not _require_param(param_name):
		return null
	return _values.get(param_name)


func reset_param(param_name: StringName) -> void:
	var param := _require_param(param_name)
	if param:
		set_param(param_name, param.default_value)


## Resets every param to its default; [signal param_changed] fires only for changed ones.
func reset_all() -> void:
	for param in params:
		if param:
			set_param(param.name, param.default_value)


## Schedules one re-render of the viewport.
func request_update() -> void:
	render_target_update_mode = SubViewport.UPDATE_ONCE
	output_changed.emit()


## Re-reads the size of [member input_tex] and resizes the viewport to match. Only requests
## a re-render when the size actually changed.
## Zero-size textures are ignored (the previous size is kept). Safe to call at any time.
func refresh_size() -> void:
	if not input_tex:
		return
	var tex_size := Vector2i(input_tex.get_size())
	if tex_size.x > 0 and tex_size.y > 0 and tex_size != size:
		size = tex_size
		request_update()


## Re-reads [member params]: fills in missing values, clamps existing ones and pushes
## everything to the shader. Call after mutating [member params] in place.
func sync_params() -> void:
	var synced := {}
	for param in params:
		if not param:
			continue
		var value: Variant = _values.get(param.name, param.default_value)
		synced[param.name] = param.clamp_value(value)
		_material.set_shader_parameter(param.name, synced[param.name])
	for old_name in _values:
		if not synced.has(old_name):
			_material.set_shader_parameter(old_name, null)
	var changed_values := {}
	for param_name in synced:
		if _values.has(param_name) and not is_same(_values[param_name], synced[param_name]):
			changed_values[param_name] = synced[param_name]
	_values = synced
	request_update()
	for param_name in changed_values:
		param_changed.emit(param_name, changed_values[param_name])


func get_output() -> Texture2D:
	return get_texture()


## The layer's single material. Its shader is [member shader], or the passthrough shader when
## the layer is disabled or has no shader.
func get_layer_material() -> ShaderMaterial:
	return _material


func _require_param(param_name: StringName) -> LayerParam:
	for param in params:
		if param and param.name == param_name:
			return param
	push_warning("Layer '%s': unknown param '%s'" % [name, param_name])
	return null


func _watch_params() -> void:
	for old in _watched_params:
		if old.changed.is_connected(sync_params):
			old.changed.disconnect(sync_params)
	_watched_params.clear()
	for param in params:
		if param and not _watched_params.has(param):
			param.changed.connect(sync_params)
			_watched_params.append(param)


func _disconnect_input_tex() -> void:
	if is_instance_valid(input_tex) and input_tex.changed.is_connected(_on_input_tex_changed):
		input_tex.changed.disconnect(_on_input_tex_changed)


func _on_input_tex_changed() -> void:
	refresh_size()
	request_update()


func _apply_shader() -> void:
	_material.shader = shader if (enabled and shader) else PASSTHROUGH_SHADER
	request_update()
