class_name ParamControl
extends RefCounted
## Builds the editor control matching a [LayerParam] type.
##
## FLOAT/INT get a slider with a value label, BOOL a check box, COLOR a color picker button
## and ENUM an option button. Use [method get_input] to reach the actual input widget and
## [method set_value] to update a control without triggering the change callback.

const _SYNCING_META := &"param_control_syncing"
const _INPUT_META := &"param_control_input"
const _LABEL_META := &"param_control_label"
const _DEFAULT_FLOAT_STEP := 0.001


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
			_update_label(control, param, shown)
		LayerParam.Type.BOOL:
			(input as CheckBox).set_pressed_no_signal(shown)
		LayerParam.Type.COLOR:
			(input as ColorPickerButton).color = shown
		LayerParam.Type.ENUM:
			if (input as OptionButton).item_count > 0:
				(input as OptionButton).select(shown)
	input.set_meta(_SYNCING_META, false)


static func _build_slider(param: LayerParam) -> Control:
	var slider := HSlider.new()
	var lower := minf(param.min_value, param.max_value)
	var upper := maxf(param.min_value, param.max_value)
	slider.min_value = lower
	slider.max_value = upper
	if param.type == LayerParam.Type.INT:
		slider.step = maxf(1.0, roundf(param.step))
	else:
		slider.step = param.step if param.step > 0.0 else _DEFAULT_FLOAT_STEP
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(80, 0)
	var label := Label.new()
	label.custom_minimum_size = Vector2(48, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var row := HBoxContainer.new()
	row.add_child(slider)
	row.add_child(label)
	row.set_meta(_INPUT_META, slider)
	row.set_meta(_LABEL_META, label)
	return row


static func _update_label(control: Control, param: LayerParam, value: Variant) -> void:
	if not control.has_meta(_LABEL_META):
		return
	var label := control.get_meta(_LABEL_META) as Label
	if label:
		label.text = str(int(value)) if param.type == LayerParam.Type.INT else String.num(value, 3)


static func _connect(control: Control, param: LayerParam, on_changed: Callable) -> void:
	var input := get_input(control)
	var emit := func(value: Variant) -> void:
		if input.get_meta(_SYNCING_META, false):
			return
		var clamped: Variant = param.clamp_value(value)
		_update_label(control, param, clamped)
		on_changed.call(param.name, clamped)
	match param.type:
		LayerParam.Type.FLOAT, LayerParam.Type.INT:
			(input as HSlider).value_changed.connect(emit)
		LayerParam.Type.BOOL:
			(input as CheckBox).toggled.connect(emit)
		LayerParam.Type.COLOR:
			(input as ColorPickerButton).color_changed.connect(emit)
		LayerParam.Type.ENUM:
			(input as OptionButton).item_selected.connect(emit)
