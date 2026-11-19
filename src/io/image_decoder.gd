class_name ImageDecoder
extends RefCounted
## Decodes encoded image bytes (PNG, JPG, WebP, BMP) into an [Image]. Pure static helpers.

## Default longest side, kept under common WebGL2 texture size limits.
const MAX_DIMENSION := 4096


## Decodes [param bytes]. The format is detected from magic bytes first, then from the
## extension of [param filename]. Returns null (with a warning) on failure.
static func decode(bytes: PackedByteArray, filename := "") -> Image:
	if bytes.is_empty():
		push_warning("ImageDecoder: no image data")
		return null
	var format := _detect_magic(bytes)
	if format.is_empty():
		format = filename.get_extension().to_lower()
	var image := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	match format:
		"png":
			err = image.load_png_from_buffer(bytes)
		"jpg", "jpeg":
			err = image.load_jpg_from_buffer(bytes)
		"webp":
			err = image.load_webp_from_buffer(bytes)
		"bmp":
			err = image.load_bmp_from_buffer(bytes)
	if err != OK or image.is_empty():
		push_warning("ImageDecoder: could not decode image (format '%s')" % format)
		return null
	return image


## Wraps [param image] in an [ImageTexture]; null-safe.
static func to_texture(image: Image) -> ImageTexture:
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


## Returns [param image] scaled down proportionally so its longest side is at most
## [param max_dim]. Never upscales; returns the same image when it already fits.
static func limit_size(image: Image, max_dim := MAX_DIMENSION) -> Image:
	if image == null or image.is_empty() or max_dim < 1:
		return image
	var longest := maxi(image.get_width(), image.get_height())
	if longest <= max_dim:
		return image
	var scale := float(max_dim) / float(longest)
	var w := maxi(1, roundi(image.get_width() * scale))
	var h := maxi(1, roundi(image.get_height() * scale))
	var result: Image = image.duplicate()
	result.resize(w, h, Image.INTERPOLATE_LANCZOS)
	return result


static func _detect_magic(bytes: PackedByteArray) -> String:
	if (
		bytes.size() >= 8
		and bytes.slice(0, 8) == PackedByteArray([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
	):
		return "png"
	if bytes.size() >= 3 and bytes[0] == 0xFF and bytes[1] == 0xD8 and bytes[2] == 0xFF:
		return "jpg"
	if bytes.size() >= 12 and bytes.slice(0, 4) == "RIFF".to_ascii_buffer():
		if bytes.slice(8, 12) == "WEBP".to_ascii_buffer():
			return "webp"
	if bytes.size() >= 2 and bytes[0] == 0x42 and bytes[1] == 0x4D:
		return "bmp"
	return ""
