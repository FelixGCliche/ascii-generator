extends GutTest

# save() / open_picker() (browser download + file input / FileDialog) are verified manually.

var _stack: LayerStack
var _io: PresetIO


func before_each() -> void:
	_stack = LayerStack.new()
	add_child_autofree(_stack)
	var layer := Layer.new()
	layer.name = "Alpha"
	_stack.add_layer(layer)
	_io = PresetIO.new()
	add_child_autofree(_io)
	watch_signals(_io)


func test_load_text_emits_preset_loaded_with_report() -> void:
	_io.load_text(_stack, '{"version":1,"layers":[{"name":"Alpha","enabled":false},{"name":"X"}]}')
	assert_signal_emitted(_io, "preset_loaded")
	assert_signal_not_emitted(_io, "preset_failed")
	var report: Dictionary = get_signal_parameters(_io, "preset_loaded")[0]
	assert_eq(report["applied"], 1)
	assert_eq(report["skipped_layers"], ["X"])
	assert_false(_stack.get_layer(0).enabled)


func test_load_text_garbage_emits_preset_failed() -> void:
	_io.load_text(_stack, "garbage")
	assert_signal_emitted(_io, "preset_failed")
	assert_signal_not_emitted(_io, "preset_loaded")
	for e in get_errors():
		e.handled = true


func test_load_text_empty_emits_preset_failed() -> void:
	_io.load_text(_stack, "")
	assert_signal_emitted(_io, "preset_failed")
	for e in get_errors():
		e.handled = true
