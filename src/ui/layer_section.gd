class_name LayerSection
extends VBoxContainer
## Collapsible editor for one [Layer]: enable, solo, reset and one control per param.
##
## Built from the layer params, so it needs no per-layer code. Control edits go through
## [method Layer.set_param]; [signal Layer.param_changed] refreshes the controls without
## re-emitting, so reset and presets show up in the UI.

var layer: Layer
var stack: LayerStack

var _header: Button
var _content: VBoxContainer
var _enabled_check: CheckBox
var _solo_check: CheckBox
var _reset_button: Button
## Param name -> control built by [ParamControl].
var _controls := {}
var _params := {}


func _init(initial_layer: Layer = null, initial_stack: LayerStack = null) -> void:
	layer = initial_layer
	stack = initial_stack


func _ready() -> void:
	if not layer:
		return
	_build()
	layer.param_changed.connect(_on_param_changed)
	if stack:
		stack.solo_changed.connect(_on_solo_changed)
	_refresh_solo()


func get_control(param_name: StringName) -> Control:
	return _controls.get(param_name)


func get_header_button() -> Button:
	return _header


func get_content() -> Control:
	return _content


func get_enabled_check() -> CheckBox:
	return _enabled_check


func get_solo_check() -> CheckBox:
	return _solo_check


func get_reset_button() -> Button:
	return _reset_button


func _build() -> void:
	_header = Button.new()
	_header.toggle_mode = true
	_header.button_pressed = true
	_header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header.toggled.connect(_on_header_toggled)
	add_child(_header)
	_content = VBoxContainer.new()
	add_child(_content)
	_update_header(true)

	var tools := HBoxContainer.new()
	_content.add_child(tools)
	_enabled_check = CheckBox.new()
	_enabled_check.text = "Enabled"
	_enabled_check.button_pressed = layer.enabled
	_enabled_check.toggled.connect(_on_enabled_toggled)
	tools.add_child(_enabled_check)
	_solo_check = CheckBox.new()
	_solo_check.text = "Solo"
	_solo_check.toggled.connect(_on_solo_toggled)
	tools.add_child(_solo_check)
	_reset_button = Button.new()
	_reset_button.text = "Reset"
	_reset_button.pressed.connect(layer.reset_all)
	tools.add_child(_reset_button)

	for param in layer.params:
		if param:
			_add_param_row(param)
	add_child(HSeparator.new())


func _add_param_row(param: LayerParam) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = param.get_display_label()
	label.custom_minimum_size = Vector2(100, 0)
	row.add_child(label)
	var control := ParamControl.build(param, layer.get_param(param.name), _on_control_changed)
	row.add_child(control)
	_content.add_child(row)
	_controls[param.name] = control
	_params[param.name] = param


func _update_header(expanded: bool) -> void:
	_header.text = ("- " if expanded else "+ ") + String(layer.name)


func _refresh_solo() -> void:
	if stack and _solo_check:
		_solo_check.set_pressed_no_signal(stack.get_solo() == layer)


func _on_header_toggled(expanded: bool) -> void:
	_content.visible = expanded
	_update_header(expanded)


func _on_enabled_toggled(pressed: bool) -> void:
	layer.enabled = pressed


func _on_solo_toggled(pressed: bool) -> void:
	if not stack:
		return
	if pressed:
		stack.set_solo(layer)
	elif stack.get_solo() == layer:
		stack.clear_solo()


func _on_solo_changed(_solo_layer: Layer) -> void:
	_refresh_solo()


func _on_control_changed(param_name: StringName, value: Variant) -> void:
	layer.set_param(param_name, value)


func _on_param_changed(param_name: StringName, value: Variant) -> void:
	if _controls.has(param_name):
		ParamControl.set_value(_controls[param_name], _params[param_name], value)
