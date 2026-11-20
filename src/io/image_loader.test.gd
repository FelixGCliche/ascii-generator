extends GutTest

# open_picker() (browser file input / FileDialog) is verified manually.

var _loader: ImageLoader


func before_each() -> void:
	_loader = ImageLoader.new()
	add_child_autofree(_loader)
	watch_signals(_loader)


func test_load_bytes_emits_image_loaded() -> void:
	var png := Image.create(6, 3, false, Image.FORMAT_RGBA8).save_png_to_buffer()
	_loader.load_bytes(png, "pic.png")
	assert_signal_emitted(_loader, "image_loaded")
	assert_signal_not_emitted(_loader, "load_failed")
	var params: Array = get_signal_parameters(_loader, "image_loaded")
	assert_eq(params[0].get_size(), Vector2(6, 3))
	assert_eq(params[1], "pic.png")


func test_load_bytes_garbage_emits_load_failed() -> void:
	_loader.load_bytes("garbage".to_utf8_buffer(), "bad.png")
	assert_signal_emitted(_loader, "load_failed")
	assert_signal_not_emitted(_loader, "image_loaded")
	for e in get_errors():
		e.handled = true  # loaders log engine errors on garbage input


func test_load_bytes_empty_emits_load_failed() -> void:
	_loader.load_bytes(PackedByteArray(), "")
	assert_signal_emitted(_loader, "load_failed")
