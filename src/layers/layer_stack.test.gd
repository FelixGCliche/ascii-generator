extends GutTest

var _stack: LayerStack


func before_each() -> void:
	_stack = LayerStack.new()
	add_child_autofree(_stack)


func _source(w := 16, h := 8) -> ImageTexture:
	return ImageTexture.create_from_image(Image.create(w, h, false, Image.FORMAT_RGBA8))


func test_empty_stack_final_texture() -> void:
	assert_null(_stack.get_final_texture())
	var src := _source()
	_stack.source_texture = src
	assert_eq(_stack.get_final_texture(), src)


func test_chain_order_and_inputs() -> void:
	var src := _source()
	_stack.source_texture = src
	var a := Layer.new()
	var b := Layer.new()
	var c := Layer.new()
	_stack.add_layer(a)
	_stack.add_layer(b)
	_stack.add_layer(c)
	assert_eq(_stack.get_layers(), [a, b, c])
	assert_eq(_stack.get_layer(1), b)
	assert_null(_stack.get_layer(5))
	assert_eq(a.input_tex, src)
	assert_eq(b.input_tex, a.get_output())
	assert_eq(c.input_tex, b.get_output())
	assert_eq(_stack.get_final_texture(), c.get_output())
	assert_eq(a.get_parent(), _stack)
	assert_eq(a.size, Vector2i(16, 8))


func test_source_change_rechains() -> void:
	var a := Layer.new()
	_stack.add_layer(a)
	assert_null(a.input_tex)
	var src := _source(4, 4)
	_stack.source_texture = src
	assert_eq(a.input_tex, src)
	assert_eq(a.size, Vector2i(4, 4))


func test_insert_at_index() -> void:
	var a := Layer.new()
	var b := Layer.new()
	_stack.add_layer(a)
	_stack.add_layer(b, 0)
	assert_eq(_stack.get_layers(), [b, a])
	assert_eq(a.input_tex, b.get_output())


func test_remove_rechains() -> void:
	var src := _source()
	_stack.source_texture = src
	var a := Layer.new()
	var b := Layer.new()
	var c := Layer.new()
	for layer in [a, b, c]:
		_stack.add_layer(layer)
	_stack.remove_layer(b)
	assert_eq(_stack.get_layers(), [a, c])
	assert_eq(c.input_tex, a.get_output())
	assert_null(b.input_tex)
	assert_null(b.get_parent())
	assert_false(a.output_changed.is_connected(b.refresh_size))
	b.free()


func test_move_rechains() -> void:
	var src := _source()
	_stack.source_texture = src
	var a := Layer.new()
	var b := Layer.new()
	_stack.add_layer(a)
	_stack.add_layer(b)
	_stack.move_layer(b, 0)
	assert_eq(_stack.get_layers(), [b, a])
	assert_eq(b.input_tex, src)
	assert_eq(a.input_tex, b.get_output())
	assert_eq(_stack.get_final_texture(), a.get_output())
	assert_false(a.output_changed.is_connected(b.refresh_size))
	assert_true(b.output_changed.is_connected(a.refresh_size))


func test_solo_select_and_clear() -> void:
	var a := Layer.new()
	var b := Layer.new()
	_stack.add_layer(a)
	_stack.add_layer(b)
	_stack.set_solo(a)
	assert_eq(_stack.get_solo(), a)
	assert_eq(_stack.get_final_texture(), a.get_output())
	assert_eq(b.input_tex, a.get_output())
	_stack.clear_solo()
	assert_null(_stack.get_solo())
	assert_eq(_stack.get_final_texture(), b.get_output())


func test_solo_ignores_foreign_layer_and_clears_on_remove() -> void:
	var a := Layer.new()
	var other := Layer.new()
	_stack.add_layer(a)
	_stack.set_solo(other)
	assert_null(_stack.get_solo())
	_stack.set_solo(a)
	_stack.remove_layer(a)
	assert_null(_stack.get_solo())
	a.free()
	other.free()


func test_final_texture_changed_signal() -> void:
	var a := Layer.new()
	var b := Layer.new()
	_stack.add_layer(a)
	watch_signals(_stack)
	_stack.add_layer(b)
	assert_signal_emit_count(_stack, "final_texture_changed", 1)
	assert_signal_emitted_with_parameters(_stack, "final_texture_changed", [b.get_output()])
	_stack.set_solo(a)
	assert_signal_emit_count(_stack, "final_texture_changed", 2)
	_stack.set_solo(a)
	assert_signal_emit_count(_stack, "final_texture_changed", 2)
	_stack.clear_solo()
	assert_signal_emit_count(_stack, "final_texture_changed", 3)


func test_upstream_output_changed_refreshes_downstream() -> void:
	var a := Layer.new()
	var b := Layer.new()
	_stack.add_layer(a)
	_stack.add_layer(b)
	b.render_target_update_mode = SubViewport.UPDATE_DISABLED
	a.request_update()
	assert_eq(b.render_target_update_mode, SubViewport.UPDATE_ONCE)
	b.render_target_update_mode = SubViewport.UPDATE_DISABLED
	a.enabled = false
	assert_eq(b.render_target_update_mode, SubViewport.UPDATE_ONCE)


func test_removed_layer_no_longer_propagates() -> void:
	var a := Layer.new()
	var b := Layer.new()
	_stack.add_layer(a)
	_stack.add_layer(b)
	_stack.remove_layer(b)
	b.render_target_update_mode = SubViewport.UPDATE_DISABLED
	a.request_update()
	assert_eq(b.render_target_update_mode, SubViewport.UPDATE_DISABLED)
	b.free()
