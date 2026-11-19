class_name LayerPanel
extends ScrollContainer
## Scrollable list of [LayerSection]s, one per layer of a [LayerStack].
##
## Rebuilds whenever the stack layers change.

var stack: LayerStack:
	set(value):
		if value == stack:
			return
		if stack and stack.layers_changed.is_connected(_rebuild):
			stack.layers_changed.disconnect(_rebuild)
		stack = value
		if stack:
			stack.layers_changed.connect(_rebuild)
		_rebuild()

var _list := VBoxContainer.new()
var _sections: Array[LayerSection] = []


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_list)


func get_sections() -> Array[LayerSection]:
	return _sections.duplicate()


func _rebuild() -> void:
	for section in _sections:
		_list.remove_child(section)
		section.queue_free()
	_sections.clear()
	if not stack:
		return
	for layer in stack.get_layers():
		var section := LayerSection.new(layer, stack)
		section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_list.add_child(section)
		_sections.append(section)
