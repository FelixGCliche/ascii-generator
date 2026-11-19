extends GutTest

# Platform pickers (browser file input, FileDialog) are verified manually.


# Decoding garbage makes Godot's loaders log engine errors; those are expected here.
func _expect_errors() -> void:
	for e in get_errors():
		e.handled = true


func _image(w := 8, h := 4) -> Image:
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	return image


func test_decode_png() -> void:
	var image := ImageDecoder.decode(_image().save_png_to_buffer(), "a.png")
	assert_not_null(image)
	assert_eq(image.get_size(), Vector2i(8, 4))


func test_decode_jpg() -> void:
	var image := ImageDecoder.decode(_image().save_jpg_to_buffer(), "a.jpg")
	assert_not_null(image)
	assert_eq(image.get_size(), Vector2i(8, 4))


func test_decode_webp() -> void:
	var image := ImageDecoder.decode(_image().save_webp_to_buffer(), "a.webp")
	assert_not_null(image)
	assert_eq(image.get_size(), Vector2i(8, 4))


func test_decode_bmp_header_is_detected() -> void:
	# Godot has no BMP encoder; hand-build a 1x1 24-bit BMP.
	var bmp := PackedByteArray([0x42, 0x4D, 58, 0, 0, 0, 0, 0, 0, 0, 54, 0, 0, 0])
	bmp.append_array(PackedByteArray([40, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 24, 0]))
	bmp.append_array(
		PackedByteArray([0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	)
	bmp.append_array(PackedByteArray([0, 0, 255, 0]))
	assert_eq(ImageDecoder._detect_magic(bmp), "bmp")
	var image := ImageDecoder.decode(bmp, "")
	if image != null:
		assert_eq(image.get_size(), Vector2i(1, 1))
	else:
		pending("BMP decoding unsupported by this Godot build")


func test_magic_bytes_beat_wrong_extension() -> void:
	var image := ImageDecoder.decode(_image().save_png_to_buffer(), "photo.jpg")
	assert_not_null(image)


func test_extension_fallback_without_magic() -> void:
	assert_eq(ImageDecoder._detect_magic(PackedByteArray([1, 2, 3])), "")
	assert_null(ImageDecoder.decode(PackedByteArray([1, 2, 3]), "x.png"))
	_expect_errors()


func test_empty_bytes_returns_null() -> void:
	assert_null(ImageDecoder.decode(PackedByteArray(), "a.png"))


func test_garbage_bytes_returns_null() -> void:
	assert_null(ImageDecoder.decode("not an image".to_utf8_buffer(), "a.png"))
	assert_null(ImageDecoder.decode("not an image".to_utf8_buffer()))
	_expect_errors()


func test_limit_size_downscales_proportionally() -> void:
	var limited := ImageDecoder.limit_size(_image(200, 100), 100)
	assert_eq(limited.get_size(), Vector2i(100, 50))


func test_limit_size_portrait() -> void:
	var limited := ImageDecoder.limit_size(_image(100, 400), 200)
	assert_eq(limited.get_size(), Vector2i(50, 200))


func test_limit_size_never_upscales() -> void:
	var image := _image(10, 10)
	assert_eq(ImageDecoder.limit_size(image, 100).get_size(), Vector2i(10, 10))


func test_limit_size_null_safe() -> void:
	assert_null(ImageDecoder.limit_size(null))


func test_to_texture_size() -> void:
	var texture := ImageDecoder.to_texture(_image(8, 4))
	assert_eq(texture.get_size(), Vector2(8, 4))


func test_to_texture_null_safe() -> void:
	assert_null(ImageDecoder.to_texture(null))
