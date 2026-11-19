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

const PASSTHROUGH_SHADER := preload("res://src/shaders/passthrough.gdshader")
const INPUT_UNIFORM := &"input_tex"

@export var shader: Shader:
	set(value):
		shader = value
		_material.shader = value
		_update_active_material()
		request_update()
@export var params: Array[LayerParam] = []:
	set(value):
		params = value
		_sync_params()
@export var enabled := true:
	set(value):
		enabled = value
		_update_active_material()
		request_update()

var input_tex: Texture2D:
	set(value):
		if input_tex and input_tex.changed.is_connected(refresh_size):
			input_tex.changed.disconnect(refresh_size)
		input_tex = value
		_material.set_shader_parameter(INPUT_UNIFORM, value)
		_passthrough_material.set_shader_parameter(INPUT_UNIFORM, value)
		if value and not value.changed.is_connected(refresh_size):
			value.changed.connect(refresh_size)
		refresh_size()

var _material := ShaderMaterial.new()
var _passthrough_material := ShaderMaterial.new()
var _values := {}
var _rect := ColorRect.new()


func _init() -> void:
	_passthrough_material.shader = PASSTHROUGH_SHADER
	render_target_update_mode = SubViewport.UPDATE_ONCE
	transparent_bg = true
	disable_3d = true
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_rect, false, Node.INTERNAL_MODE_FRONT)
	_update_active_material()


func _ready() -> void:
	_sync_params()


func set_param(param_name: StringName, value: Variant) -> void:
	var param := _require_param(param_name)
	if not param:
		return
	var clamped: Variant = param.clamp_value(value)
	if _values.has(param_name):
		var old: Variant = _values[param_name]
		if typeof(old) == typeof(clamped) and old == clamped:
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


## Re-reads the size of [member input_tex] and resizes the viewport to match.
## Zero-size textures are ignored (the previous size is kept). Safe to call at any time.
func refresh_size() -> void:
	if input_tex:
		var tex_size := Vector2i(input_tex.get_size())
		if tex_size.x > 0 and tex_size.y > 0 and tex_size != size:
			size = tex_size
	request_update()


func get_output() -> Texture2D:
	return get_texture()


## The material currently drawing the layer (own shader or passthrough).
func get_active_material() -> ShaderMaterial:
	return _rect.material


## The layer's own material. Always the same instance; its shader is null when [member shader]
## is null, in which case the active material is the passthrough one.
func get_layer_material() -> ShaderMaterial:
	return _material


func get_passthrough_material() -> ShaderMaterial:
	return _passthrough_material


func _find_param(param_name: StringName) -> LayerParam:
	for param in params:
		if param and param.name == param_name:
			return param
	return null


func _require_param(param_name: StringName) -> LayerParam:
	var param := _find_param(param_name)
	if not param:
		push_warning("Layer '%s': unknown param '%s'" % [name, param_name])
	return param


## Initialises params missing a value to their default and pushes every value to the shader.
## Uniforms of params that were dropped are cleared.
func _sync_params() -> void:
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
	_values = synced
	request_update()


func _update_active_material() -> void:
	_rect.material = _material if enabled and shader else _passthrough_material
