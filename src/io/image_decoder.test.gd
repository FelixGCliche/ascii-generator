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


# Godot has no BMP encoder; hand-build a 1x1 24-bit BMP (header 14 + DIB 40 + one padded row).
func _bmp(dib_size := 40) -> PackedByteArray:
	var bmp := PackedByteArray()
	bmp.resize(58)
	bmp[0] = 0x42
	bmp[1] = 0x4D
	bmp.encode_u32(2, 58)
	bmp.encode_u32(10, 54)
	bmp.encode_u32(14, dib_size)
	bmp.encode_s32(18, 1)
	bmp.encode_s32(22, 1)
	bmp.encode_u16(26, 1)
	bmp.encode_u16(28, 24)
	bmp.encode_u32(34, 4)
	bmp[56] = 255  # pixel BGR = (0, 0, 255) -> red
	return bmp


func test_decode_bmp() -> void:
	var image := ImageDecoder.decode(_bmp(), "")
	assert_not_null(image)
	assert_eq(image.get_size(), Vector2i(1, 1))
	assert_eq(image.get_pixel(0, 0).r8, 255)


func test_bmp_with_invalid_dib_size_is_not_claimed_by_magic() -> void:
	# "BM" prefix but a bogus DIB header size: no magic match and no extension to fall back on,
	# even though Godot's own BMP loader is lenient enough to decode these bytes.
	assert_null(ImageDecoder.decode(_bmp(41), ""))
	_expect_errors()


func test_bmp_with_invalid_dib_size_decodes_via_extension() -> void:
	var image := ImageDecoder.decode(_bmp(41), "x.bmp")
	assert_not_null(image)
	assert_eq(image.get_size(), Vector2i(1, 1))


func test_magic_bytes_beat_wrong_extension() -> void:
	var image := ImageDecoder.decode(_image().save_png_to_buffer(), "photo.jpg")
	assert_not_null(image)


func test_failed_magic_decoder_still_tries_extension_then_returns_null() -> void:
	# Truncated BMP: magic picks bmp and fails, the .png fallback fails too.
	assert_null(ImageDecoder.decode(_bmp().slice(0, 30), "x.png"))
	_expect_errors()


func test_extension_decoder_used_without_magic() -> void:
	# Headerless garbage with a known extension is attempted by that decoder and fails cleanly.
	assert_null(ImageDecoder.decode(PackedByteArray([1, 2, 3]), "x.png"))
	_expect_errors()


func test_empty_bytes_returns_null() -> void:
	assert_null(ImageDecoder.decode(PackedByteArray(), "a.png"))


func test_garbage_bytes_returns_null() -> void:
	assert_null(ImageDecoder.decode("not an image".to_utf8_buffer(), "a.png"))
	assert_null(ImageDecoder.decode("not an image".to_utf8_buffer()))
	_expect_errors()


func test_limit_size_downscales_proportionally() -> void:
	var image := _image(200, 100)
	var limited := ImageDecoder.limit_size(image, 100)
	assert_eq(limited.get_size(), Vector2i(100, 50))
	assert_same(limited, image, "resizes in place")


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
