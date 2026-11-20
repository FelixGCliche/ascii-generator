extends GutTest

var _stack: LayerStack
var _layer: Layer
var _section: LayerSection


func before_each() -> void:
	_stack = LayerStack.new()
	add_child_autofree(_stack)
	_layer = Layer.new()
	_layer.name = &"Blur"
	var amount := LayerParam.new()
	amount.name = &"amount"
	amount.label = "Blur amount"
	amount.min_value = 0.0
	amount.max_value = 10.0
	amount.default_value = 2.0
	var invert := LayerParam.new()
	invert.name = &"invert"
	invert.type = LayerParam.Type.BOOL
	invert.default_value = false
	var typed: Array[LayerParam] = [amount, invert]
	_layer.params = typed
	_stack.add_layer(_layer)
	_section = LayerSection.new(_layer, _stack)
	add_child_autofree(_section)


func _slider(param_name: StringName) -> HSlider:
	return ParamControl.get_input(_section.get_control(param_name)) as HSlider


func test_builds_one_control_per_param_with_labels() -> void:
	assert_not_null(_section.get_control(&"amount"))
	assert_not_null(_section.get_control(&"invert"))
	assert_eq(_section.get_header_button().text, "- Blur")
	var labels: Array[String] = []
	for row in _section.get_content().get_children():
		for child in row.get_children():
			if child is Label:
				labels.append(child.text)
	assert_has(labels, "Blur amount")
	assert_has(labels, "invert")


func test_initial_values_shown() -> void:
	assert_eq(_slider(&"amount").value, 2.0)


func test_edit_writes_to_layer_with_clamping() -> void:
	_slider(&"amount").value = 7.0
	assert_eq(_layer.get_param(&"amount"), 7.0)
	var box := _section.get_control(&"invert") as CheckBox
	box.button_pressed = true
	assert_eq(_layer.get_param(&"invert"), true)


func test_external_change_updates_control_without_loop() -> void:
	watch_signals(_layer)
	_layer.set_param(&"amount", 9.0)
	assert_eq(_slider(&"amount").value, 9.0)
	assert_signal_emit_count(_layer, "param_changed", 1)


func test_enable_toggle_sets_layer_enabled() -> void:
	_section.get_enabled_check().button_pressed = false
	assert_false(_layer.enabled)
	_section.get_enabled_check().button_pressed = true
	assert_true(_layer.enabled)


func test_solo_toggle_sets_and_clears_stack_solo() -> void:
	_section.get_solo_check().button_pressed = true
	assert_eq(_stack.get_solo(), _layer)
	_section.get_solo_check().button_pressed = false
	assert_null(_stack.get_solo())


func test_solo_reflects_external_changes() -> void:
	_stack.set_solo(_layer)
	assert_true(_section.get_solo_check().button_pressed)
	_stack.clear_solo()
	assert_false(_section.get_solo_check().button_pressed)


func test_reset_restores_defaults_and_refreshes_controls() -> void:
	_slider(&"amount").value = 8.0
	(_section.get_control(&"invert") as CheckBox).button_pressed = true
	_section.get_reset_button().pressed.emit()
	assert_eq(_layer.get_param(&"amount"), 2.0)
	assert_eq(_layer.get_param(&"invert"), false)
	assert_eq(_slider(&"amount").value, 2.0)
	assert_false((_section.get_control(&"invert") as CheckBox).button_pressed)


func test_header_toggle_collapses_content() -> void:
	_section.get_header_button().button_pressed = false
	assert_false(_section.get_content().visible)
	assert_eq(_section.get_header_button().text, "+ Blur")
	_section.get_header_button().button_pressed = true
	assert_true(_section.get_content().visible)
