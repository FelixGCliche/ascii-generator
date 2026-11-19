extends GutTest

var _stack: LayerStack


class SizedTexture:
	extends Texture2D
	var w := 8

	func _get_width() -> int:
		return w

	func _get_height() -> int:
		return 8


func before_each() -> void:
	_stack = LayerStack.new()
	add_child_autofree(_stack)


func _source(w := 16, h := 8) -> ImageTexture:
	return ImageTexture.create_from_image(Image.create(w, h, false, Image.FORMAT_RGBA8))


func _three(src: Texture2D = null) -> Array[Layer]:
	_stack.source_texture = src if src else _source(16, 8)
	var layers: Array[Layer] = [Layer.new(), Layer.new(), Layer.new()]
	for layer in layers:
		_stack.add_layer(layer)
	return layers


func test_source_resize_reaches_all_layers() -> void:
	var layers := _three()
	_stack.source_texture = _source(40, 20)
	for layer in layers:
		assert_eq(layer.size, Vector2i(40, 20))


func test_rechain_refreshes_unchanged_input_textures() -> void:
	var tex := SizedTexture.new()
	var layers := _three(tex)
	assert_eq(layers[2].size, Vector2i(8, 8))
	tex.w = 30
	# Same texture objects everywhere: only an explicit refresh can pick the size up.
	_stack.move_layer(layers[2], 2)
	for layer in layers:
		assert_eq(layer.size, Vector2i(30, 8))
	tex.w = 12
	_stack.move_layer(layers[0], 1)
	for layer in layers:
		assert_eq(layer.size, Vector2i(12, 8))
	tex.w = 6
	_stack.remove_layer(layers[1])
	assert_eq(layers[0].size, Vector2i(6, 8))
	assert_eq(layers[2].size, Vector2i(6, 8))
	layers[1].free()


func test_externally_freed_layer_is_dropped() -> void:
	var layers := _three()
	_stack.set_solo(layers[1])
	layers[1].free()
	assert_eq(_stack.get_layers(), [layers[0], layers[2]])
	assert_null(_stack.get_solo())
	assert_eq(layers[2].input_tex, layers[0].get_output())
	assert_eq(_stack.get_final_texture(), layers[2].get_output())


func test_freed_layer_while_stack_outside_tree() -> void:
	var stack := LayerStack.new()
	var a := Layer.new()
	var b := Layer.new()
	stack.add_layer(a)
	stack.add_layer(b)
	a.free()
	assert_eq(stack.get_layers(), [b])
	stack.free()


func test_stack_leaving_tree_keeps_layers() -> void:
	var layers := _three()
	remove_child(_stack)
	add_child(_stack)
	await wait_frames(1)
	assert_eq(_stack.get_layers(), layers)


func test_layer_removed_from_tree_externally_is_dropped() -> void:
	var layers := _three()
	_stack.remove_child(layers[1])
	await wait_frames(1)
	assert_eq(_stack.get_layers(), [layers[0], layers[2]])
	assert_eq(layers[2].input_tex, layers[0].get_output())
	layers[1].free()


func test_add_layer_moves_from_other_stack() -> void:
	var other := LayerStack.new()
	add_child_autofree(other)
	var src := _source()
	other.source_texture = src
	var a := Layer.new()
	var b := Layer.new()
	other.add_layer(a)
	other.add_layer(b)
	_stack.add_layer(a)
	assert_eq(other.get_layers(), [b])
	assert_eq(_stack.get_layers(), [a])
	assert_eq(a.get_parent(), _stack)
	assert_eq(b.input_tex, src)
	assert_null(a.input_tex)
	# No stale links: a only feeds its new downstream layer.
	_stack.add_layer(Layer.new())
	assert_eq(a.output_changed.get_connections().size(), 1)
	# A layer with a plain parent is adopted too.
	var plain := Node.new()
	add_child_autofree(plain)
	var c := Layer.new()
	plain.add_child(c)
	_stack.add_layer(c)
	assert_eq(c.get_parent(), _stack)


func test_downstream_update_is_deferred_and_coalesced() -> void:
	var layers := _three()
	for i in 3:
		_stack._flush_pending()
	for layer in layers:
		layer.render_target_update_mode = SubViewport.UPDATE_DISABLED
	watch_signals(layers[1])
	layers[0].request_update()
	layers[0].request_update()
	layers[0].request_update()
	assert_eq(layers[1].render_target_update_mode, SubViewport.UPDATE_DISABLED)
	_stack._flush_pending()
	assert_eq(layers[1].render_target_update_mode, SubViewport.UPDATE_ONCE)
	assert_signal_emit_count(layers[1], "output_changed", 1)
	# Layer 2 is queued by layer 1's request, one stage later.
	assert_eq(layers[2].render_target_update_mode, SubViewport.UPDATE_DISABLED)
	_stack._flush_pending()
	assert_eq(layers[2].render_target_update_mode, SubViewport.UPDATE_ONCE)


func test_flush_runs_on_frame_post_draw() -> void:
	var layers := _three()
	for i in 3:
		_stack._flush_pending()
	layers[1].render_target_update_mode = SubViewport.UPDATE_DISABLED
	watch_signals(_stack)
	layers[0].request_update()
	assert_signal_not_emitted(_stack, "updates_flushed")
	# Headless runs never emit the real signal, so emit it by hand.
	RenderingServer.frame_post_draw.emit()
	assert_signal_emit_count(_stack, "updates_flushed", 1)
	assert_signal_emitted_with_parameters(_stack, "updates_flushed", [[layers[1]]])
	assert_eq(layers[1].render_target_update_mode, SubViewport.UPDATE_ONCE)


func test_no_updates_downstream_of_solo() -> void:
	var layers := _three()
	for i in 3:
		_stack._flush_pending()
	_stack.set_solo(layers[1])
	_stack._flush_pending()
	for layer in layers:
		layer.render_target_update_mode = SubViewport.UPDATE_DISABLED
	layers[1].request_update()
	_stack._flush_pending()
	assert_eq(layers[2].render_target_update_mode, SubViewport.UPDATE_DISABLED)
	layers[0].request_update()
	_stack._flush_pending()
	assert_eq(layers[1].render_target_update_mode, SubViewport.UPDATE_ONCE)
	assert_eq(layers[2].render_target_update_mode, SubViewport.UPDATE_DISABLED)
	# Leaving solo brings the hidden layer back up to date.
	_stack.clear_solo()
	_stack._flush_pending()
	assert_eq(layers[2].render_target_update_mode, SubViewport.UPDATE_ONCE)


func test_clearing_solo_resizes_hidden_layers() -> void:
	var layers := _three()
	_stack.set_solo(layers[0])
	_stack.source_texture = _source(50, 10)
	assert_eq(layers[0].size, Vector2i(50, 10))
	_stack.clear_solo()
	assert_eq(layers[2].size, Vector2i(50, 10))


func test_flush_skips_freed_queued_layer() -> void:
	var layers := _three()
	_stack._flush_pending()
	layers[0].request_update()
	layers[1].request_update()
	layers[1].free()
	watch_signals(_stack)
	_stack._flush_pending()
	assert_signal_emitted(_stack, "updates_flushed")
	var flushed: Array = get_signal_parameters(_stack, "updates_flushed")[0]
	assert_eq(flushed, [layers[2]])


func test_foreign_layer_is_not_active() -> void:
	_three()
	for i in 4:
		_stack._flush_pending()
	var foreign := Layer.new()
	assert_false(_stack._is_active(foreign))
	_stack._queue(foreign)
	watch_signals(_stack)
	_stack._flush_pending()
	assert_signal_not_emitted(_stack, "updates_flushed")
	foreign.free()


func test_removed_layer_is_not_active() -> void:
	var layers := _three()
	_stack.remove_layer(layers[1])
	assert_false(_stack._is_active(layers[1]))
	layers[1].free()
