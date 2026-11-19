extends GutTest

var _stack: LayerStack
var _panel: LayerPanel


func before_each() -> void:
	_stack = LayerStack.new()
	add_child_autofree(_stack)
	_panel = LayerPanel.new()
	add_child_autofree(_panel)
	_panel.stack = _stack


func _layer(layer_name: String) -> Layer:
	var layer := Layer.new()
	layer.name = layer_name
	return layer


func test_empty_stack_has_no_sections() -> void:
	assert_eq(_panel.get_sections().size(), 0)


func test_builds_section_per_layer() -> void:
	_stack.add_layer(_layer("A"))
	_stack.add_layer(_layer("B"))
	_stack.add_layer(_layer("C"))
	assert_eq(_panel.get_sections().size(), 3)
	assert_eq(_panel.get_sections()[1].layer, _stack.get_layer(1))


func test_rebuilds_on_remove_and_move() -> void:
	var a := _layer("A")
	var b := _layer("B")
	_stack.add_layer(a)
	_stack.add_layer(b)
	_stack.move_layer(a, 1)
	assert_eq(_panel.get_sections()[0].layer, b)
	_stack.remove_layer(b)
	assert_eq(_panel.get_sections().size(), 1)
	assert_eq(_panel.get_sections()[0].layer, a)
	b.free()


func test_builds_from_existing_layers_when_stack_assigned() -> void:
	var other := LayerStack.new()
	add_child_autofree(other)
	other.add_layer(_layer("A"))
	_panel.stack = other
	assert_eq(_panel.get_sections().size(), 1)
