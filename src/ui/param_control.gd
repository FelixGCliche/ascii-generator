class_name ParamControl
extends RefCounted
## Builds the editor control matching a [LayerParam] type.
##
## FLOAT/INT get a slider with an editable spin box, BOOL a check box, COLOR a color picker button
## and ENUM an option button. Use [method get_input] to reach the actual input widget and
## [method set_value] to update a control without triggering the change callback.

const _SYNCING_META := &"param_control_syncing"
const _INPUT_META := &"param_control_input"
const _SPIN_META := &"param_control_spin"
const _DEFAULT_FLOAT_STEP := 0.001
const _SPIN_ICONS: Array[StringName] = [
	&"updown",
	&"up",
	&"up_hover",
	&"up_pressed",
	&"up_disabled",
	&"down",
	&"down_hover",
	&"down_pressed",
	&"down_disabled",
]


## Returns a control for [param param] showing [param current_value]. [param on_changed] is
## called as [code]on_changed(param_name, value)[/code] on user edits only.
static func build(param: LayerParam, current_value: Variant, on_changed: Callable) -> Control:
	var control: Control
	match param.type:
		LayerParam.Type.FLOAT, LayerParam.Type.INT:
			control = _build_slider(param)
		LayerParam.Type.BOOL:
			control = CheckBox.new()
		LayerParam.Type.COLOR:
			var picker := ColorPickerButton.new()
			picker.custom_minimum_size = Vector2(48, 0)
			control = picker
		LayerParam.Type.ENUM:
			var option := OptionButton.new()
			for item in param.options:
				option.add_item(item)
			control = option
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set_value(control, param, current_value)
	_connect(control, param, on_changed)
	return control


## The widget the user edits: the control itself, or the slider inside a numeric row.
static func get_input(control: Control) -> Control:
	return control.get_meta(_INPUT_META, control)


## Shows [param value] in [param control] without calling the change callback.
static func set_value(control: Control, param: LayerParam, value: Variant) -> void:
	var input := get_input(control)
	var shown: Variant = param.clamp_value(value)
	input.set_meta(_SYNCING_META, true)
	match param.type:
		LayerParam.Type.FLOAT, LayerParam.Type.INT:
			(input as HSlider).set_value_no_signal(shown)
			_update_spin(control, shown)
		LayerParam.Type.BOOL:
			(input as CheckBox).set_pressed_no_signal(shown)
		LayerParam.Type.COLOR:
			(input as ColorPickerButton).color = shown
		LayerParam.Type.ENUM:
			if (input as OptionButton).item_count > 0:
				(input as OptionButton).select(shown)
	input.set_meta(_SYNCING_META, false)


static func _build_slider(param: LayerParam) -> Control:
	var lower := minf(param.min_value, param.max_value)
	var upper := maxf(param.min_value, param.max_value)
	var step: float
	if param.type == LayerParam.Type.INT:
		step = maxf(1.0, roundf(param.step))
	else:
		step = param.step if param.step > 0.0 else _DEFAULT_FLOAT_STEP
	var slider := HSlider.new()
	slider.min_value = lower
	slider.max_value = upper
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(80, 0)
	var spin := SpinBox.new()
	spin.min_value = lower
	spin.max_value = upper
	spin.step = step
	spin.editable = true
	spin.custom_minimum_size = Vector2(64, 0)
	spin.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hide_spin_arrows(spin)
	var row := HBoxContainer.new()
	row.add_child(slider)
	row.add_child(spin)
	row.set_meta(_INPUT_META, slider)
	row.set_meta(_SPIN_META, spin)
	return row


## Collapses the up/down buttons so the spin box is a plain numeric field.
static func _hide_spin_arrows(spin: SpinBox) -> void:
	var empty_icon := ImageTexture.new()
	for icon in _SPIN_ICONS:
		spin.add_theme_icon_override(icon, empty_icon)
	spin.add_theme_constant_override(&"buttons_width", 0)
	spin.add_theme_constant_override(&"set_min_buttons_width_from_icons", 0)
	spin.add_theme_constant_override(&"field_and_buttons_separation", 0)
	spin.add_theme_stylebox_override(&"field_and_buttons_separator", StyleBoxEmpty.new())


static func _get_spin(control: Control) -> SpinBox:
	if not control.has_meta(_SPIN_META):
		return null
	return control.get_meta(_SPIN_META) as SpinBox


static func _update_spin(control: Control, value: Variant) -> void:
	var spin := _get_spin(control)
	if spin:
		spin.set_value_no_signal(value)


static func _connect(control: Control, param: LayerParam, on_changed: Callable) -> void:
	var input := get_input(control)
	var spin := _get_spin(control)
	var emit := func(value: Variant) -> void:
		if input.get_meta(_SYNCING_META, false):
			return
		var clamped: Variant = param.clamp_value(value)
		if spin:
			(input as Range).set_value_no_signal(clamped)
			spin.set_value_no_signal(clamped)
		on_changed.call(param.name, clamped)
	match param.type:
		LayerParam.Type.FLOAT, LayerParam.Type.INT:
			(input as HSlider).value_changed.connect(emit)
			spin.value_changed.connect(emit)
		LayerParam.Type.BOOL:
			(input as CheckBox).toggled.connect(emit)
		LayerParam.Type.COLOR:
			(input as ColorPickerButton).color_changed.connect(emit)
		LayerParam.Type.ENUM:
			(input as OptionButton).item_selected.connect(emit)
