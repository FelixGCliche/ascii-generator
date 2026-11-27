extends GutTest

var _calls: Array = []


func before_each() -> void:
	_calls = []


func _record(param_name: StringName, value: Variant) -> void:
	_calls.append([param_name, value])


func _param(type: LayerParam.Type, default: Variant = null) -> LayerParam:
	var p := LayerParam.new()
	p.name = &"amount"
	p.type = type
	p.default_value = default
	return p


func _build(p: LayerParam, value: Variant = null) -> Control:
	var control := ParamControl.build(p, value, _record)
	add_child_autofree(control)
	return control


func test_control_class_per_type() -> void:
	assert_is(ParamControl.get_input(_build(_param(LayerParam.Type.FLOAT))), HSlider)
	assert_is(ParamControl.get_input(_build(_param(LayerParam.Type.INT))), HSlider)
	assert_is(_build(_param(LayerParam.Type.BOOL)), CheckBox)
	assert_is(_build(_param(LayerParam.Type.COLOR)), ColorPickerButton)
	var enum_param := _param(LayerParam.Type.ENUM)
	enum_param.options = PackedStringArray(["a", "b", "c"])
	var option := _build(enum_param) as OptionButton
	assert_is(option, OptionButton)
	assert_eq(option.item_count, 3)
	assert_eq(option.get_item_text(2), "c")


func test_slider_range_and_step() -> void:
	var p := _param(LayerParam.Type.FLOAT, 0.5)
	p.min_value = -2.0
	p.max_value = 4.0
	p.step = 0.5
	var slider := ParamControl.get_input(_build(p, 0.5)) as HSlider
	assert_eq(slider.min_value, -2.0)
	assert_eq(slider.max_value, 4.0)
	assert_eq(slider.step, 0.5)
	assert_eq(slider.value, 0.5)


func test_int_slider_step_at_least_one() -> void:
	var p := _param(LayerParam.Type.INT, 3)
	p.min_value = 0.0
	p.max_value = 10.0
	var slider := ParamControl.get_input(_build(p, 3)) as HSlider
	assert_eq(slider.step, 1.0)
	assert_eq(slider.value, 3.0)


func test_edit_reports_clamped_value() -> void:
	var p := _param(LayerParam.Type.FLOAT, 0.0)
	p.step = 0.25
	var slider := ParamControl.get_input(_build(p, 0.0)) as HSlider
	slider.value = 0.5
	assert_eq(_calls, [[&"amount", 0.5]])


func test_bool_edit() -> void:
	var box := _build(_param(LayerParam.Type.BOOL, false)) as CheckBox
	box.button_pressed = true
	assert_eq(_calls, [[&"amount", true]])


func test_enum_edit() -> void:
	var p := _param(LayerParam.Type.ENUM, 0)
	p.options = PackedStringArray(["a", "b"])
	var option := _build(p, 0) as OptionButton
	option.item_selected.emit(1)
	assert_eq(_calls, [[&"amount", 1]])


func test_color_edit() -> void:
	var picker := (
		_build(_param(LayerParam.Type.COLOR, Color.WHITE), Color.WHITE) as ColorPickerButton
	)
	picker.color_changed.emit(Color.RED)
	assert_eq(_calls, [[&"amount", Color.RED]])


func test_programmatic_set_does_not_emit() -> void:
	var p := _param(LayerParam.Type.FLOAT, 0.0)
	var row := _build(p, 0.0)
	ParamControl.set_value(row, p, 0.75)
	assert_eq((ParamControl.get_input(row) as HSlider).value, 0.75)
	var bool_param := _param(LayerParam.Type.BOOL, false)
	var box := _build(bool_param, false) as CheckBox
	ParamControl.set_value(box, bool_param, true)
	assert_true(box.button_pressed)
	var color_param := _param(LayerParam.Type.COLOR, Color.WHITE)
	var picker := _build(color_param, Color.WHITE) as ColorPickerButton
	ParamControl.set_value(picker, color_param, Color.BLUE)
	assert_eq(picker.color, Color.BLUE)
	assert_eq(_calls, [])
	(ParamControl.get_input(row) as HSlider).value = 0.25
	assert_eq(_calls.size(), 1)


func _spin(row: Control) -> SpinBox:
	for child in row.get_children():
		if child is SpinBox:
			return child
	return null


func _ranged_param(type: LayerParam.Type, default: Variant) -> LayerParam:
	var p := _param(type, default)
	p.min_value = -2.0
	p.max_value = 4.0
	p.step = 0.5
	return p


func test_spinbox_matches_slider_range_and_step() -> void:
	var row := _build(_ranged_param(LayerParam.Type.FLOAT, 0.5), 0.5)
	var slider := ParamControl.get_input(row) as HSlider
	var spin := _spin(row)
	assert_not_null(spin)
	assert_eq(spin.min_value, slider.min_value)
	assert_eq(spin.max_value, slider.max_value)
	assert_eq(spin.step, slider.step)
	assert_eq(spin.value, 0.5)
	assert_true(spin.editable)
	var int_param := _param(LayerParam.Type.INT, 3)
	int_param.max_value = 10.0
	var int_row := _build(int_param, 3)
	assert_eq(_spin(int_row).step, 1.0)
	assert_eq(_spin(int_row).value, 3.0)


func test_set_value_updates_slider_and_spinbox_silently() -> void:
	var p := _ranged_param(LayerParam.Type.FLOAT, 0.0)
	var row := _build(p, 0.0)
	ParamControl.set_value(row, p, 1.5)
	assert_eq((ParamControl.get_input(row) as HSlider).value, 1.5)
	assert_eq(_spin(row).value, 1.5)
	assert_eq(_calls, [])


func test_spinbox_edit_emits_once_and_moves_slider() -> void:
	var row := _build(_ranged_param(LayerParam.Type.FLOAT, 0.0), 0.0)
	_spin(row).value = 2.5
	assert_eq(_calls, [[&"amount", 2.5]])
	assert_eq((ParamControl.get_input(row) as HSlider).value, 2.5)


func test_slider_edit_updates_spinbox() -> void:
	var row := _build(_ranged_param(LayerParam.Type.FLOAT, 0.0), 0.0)
	(ParamControl.get_input(row) as HSlider).value = -1.0
	assert_eq(_spin(row).value, -1.0)
	assert_eq(_calls, [[&"amount", -1.0]])


func test_out_of_range_edit_clamps() -> void:
	var row := _build(_ranged_param(LayerParam.Type.FLOAT, 0.0), 0.0)
	_spin(row).value_changed.emit(10.0)
	assert_eq(_calls, [[&"amount", 4.0]])
	assert_eq(_spin(row).value, 4.0)
	assert_eq((ParamControl.get_input(row) as HSlider).value, 4.0)
	var p := _ranged_param(LayerParam.Type.FLOAT, 0.0)
	var other := _build(p, 0.0)
	ParamControl.set_value(other, p, -9.0)
	assert_eq(_spin(other).value, -2.0)
