class_name Layer
extends SubViewport
## One pass of the ASCII pipeline.
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
@export var params: Array[LayerParam] = []:
	set(value):
		params = value
		_sync_params()
@export var enabled := true:
	set(value):
		enabled = value
		_update_active_material()

var input_tex: Texture2D:
	set(value):
		input_tex = value
		_material.set_shader_parameter(INPUT_UNIFORM, value)
		_passthrough_material.set_shader_parameter(INPUT_UNIFORM, value)
		if value:
			size = Vector2i(value.get_size())

var _material := ShaderMaterial.new()
var _passthrough_material := ShaderMaterial.new()
var _values := {}
var _rect := ColorRect.new()


func _init() -> void:
	_passthrough_material.shader = PASSTHROUGH_SHADER
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	transparent_bg = true
	disable_3d = true
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_rect, false, Node.INTERNAL_MODE_FRONT)
	_update_active_material()


func _ready() -> void:
	_sync_params()


func set_param(param_name: StringName, value: Variant) -> void:
	var param := _find_param(param_name)
	if not param:
		push_warning("Layer '%s': unknown param '%s'" % [name, param_name])
		return
	var clamped: Variant = param.clamp_value(value)
	_values[param_name] = clamped
	_material.set_shader_parameter(param_name, clamped)
	param_changed.emit(param_name, clamped)


func get_param(param_name: StringName) -> Variant:
	if not _find_param(param_name):
		push_warning("Layer '%s': unknown param '%s'" % [name, param_name])
		return null
	return _values.get(param_name)


func reset_param(param_name: StringName) -> void:
	var param := _find_param(param_name)
	if not param:
		push_warning("Layer '%s': unknown param '%s'" % [name, param_name])
		return
	set_param(param_name, param.default_value)


func reset_all() -> void:
	for param in params:
		set_param(param.name, param.default_value)


func get_output() -> Texture2D:
	return get_texture()


## The material currently drawing the layer (own shader or passthrough).
func get_active_material() -> ShaderMaterial:
	return _rect.material


func get_layer_material() -> ShaderMaterial:
	return _material


func get_passthrough_material() -> ShaderMaterial:
	return _passthrough_material


func _find_param(param_name: StringName) -> LayerParam:
	for param in params:
		if param and param.name == param_name:
			return param
	return null


## Initialises params missing a value to their default and pushes every value to the shader.
func _sync_params() -> void:
	var synced := {}
	for param in params:
		if not param:
			continue
		var value: Variant = _values.get(param.name, param.default_value)
		synced[param.name] = param.clamp_value(value)
		_material.set_shader_parameter(param.name, synced[param.name])
	_values = synced


func _update_active_material() -> void:
	_rect.material = _material if enabled and shader else _passthrough_material
