extends GutTest

const Atlas := preload("res://tools/glyph_atlas.gd")


func _is_pure(image: Image, index: int) -> bool:
	var rect: Rect2i = Atlas.cell_rect(index)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := image.get_pixel(x, y)
			if c != Color.BLACK and c != Color.WHITE:
				return false
	return true


func _px(image: Image, index: int, x: int, y: int) -> bool:
	return image.get_pixel(index * Atlas.CELL_SIZE + x, y).r > 0.5


func _cell_bits(image: Image, index: int) -> Array:
	var bits := []
	for y in Atlas.CELL_SIZE:
		for x in Atlas.CELL_SIZE:
			bits.append(_px(image, index, x, y))
	return bits


func test_dimensions() -> void:
	var luma: Image = Atlas.build_luma_atlas()
	var edge: Image = Atlas.build_edge_atlas()
	assert_eq(luma.get_size(), Vector2i(80, 8))
	assert_eq(edge.get_size(), Vector2i(32, 8))
	assert_eq(luma.get_format(), Image.FORMAT_RGBA8)
	assert_eq(edge.get_format(), Image.FORMAT_RGBA8)


func test_cell_rect() -> void:
	assert_eq(Atlas.cell_rect(0), Rect2i(0, 0, 8, 8))
	assert_eq(Atlas.cell_rect(3), Rect2i(24, 0, 8, 8))
	assert_eq(Atlas.cell_rect(9), Rect2i(72, 0, 8, 8))


func test_cell_counts() -> void:
	assert_eq(Atlas.LUMA_GLYPHS.size(), Atlas.LUMA_LEVELS)
	assert_eq(Atlas.EDGE_BITMAPS.size(), Atlas.EDGE_GLYPHS)
	assert_eq(Atlas.build_luma_atlas().get_width(), Atlas.LUMA_LEVELS * Atlas.CELL_SIZE)
	assert_eq(Atlas.build_edge_atlas().get_width(), Atlas.EDGE_GLYPHS * Atlas.CELL_SIZE)


func test_pixels_are_pure_black_or_white() -> void:
	var luma: Image = Atlas.build_luma_atlas()
	for i in Atlas.LUMA_LEVELS:
		assert_true(_is_pure(luma, i), "luma cell %d" % i)
	var edge: Image = Atlas.build_edge_atlas()
	for i in Atlas.EDGE_GLYPHS:
		assert_true(_is_pure(edge, i), "edge cell %d" % i)


func test_luma_lit_counts_strictly_increase() -> void:
	var luma: Image = Atlas.build_luma_atlas()
	assert_eq(Atlas.lit_pixel_count(luma, 0), 0)
	for i in range(1, Atlas.LUMA_LEVELS):
		assert_gt(Atlas.lit_pixel_count(luma, i), Atlas.lit_pixel_count(luma, i - 1), "cell %d" % i)


func test_edge_vertical_has_full_column() -> void:
	var edge: Image = Atlas.build_edge_atlas()
	var found := false
	for x in Atlas.CELL_SIZE:
		var full := true
		for y in Atlas.CELL_SIZE:
			full = full and _px(edge, 0, x, y)
		found = found or full
	assert_true(found)


func test_edge_horizontal_has_full_row() -> void:
	var edge: Image = Atlas.build_edge_atlas()
	var found := false
	for y in Atlas.CELL_SIZE:
		var full := true
		for x in Atlas.CELL_SIZE:
			full = full and _px(edge, 1, x, y)
		found = found or full
	assert_true(found)


func test_diagonals_mirror_and_differ() -> void:
	var edge: Image = Atlas.build_edge_atlas()
	for y in Atlas.CELL_SIZE:
		for x in Atlas.CELL_SIZE:
			assert_eq(
				_px(edge, 2, x, y), _px(edge, 3, Atlas.CELL_SIZE - 1 - x, y), "(%d,%d)" % [x, y]
			)
	assert_ne(_cell_bits(edge, 2), _cell_bits(edge, 3))


func test_glyphs_are_unique() -> void:
	var luma: Image = Atlas.build_luma_atlas()
	var seen := []
	for i in Atlas.LUMA_LEVELS:
		var bits := _cell_bits(luma, i)
		assert_false(seen.has(bits), "luma %d duplicated" % i)
		seen.append(bits)
	var edge: Image = Atlas.build_edge_atlas()
	seen = []
	for i in Atlas.EDGE_GLYPHS:
		var bits := _cell_bits(edge, i)
		assert_false(seen.has(bits), "edge %d duplicated" % i)
		seen.append(bits)


func _assert_matches_file(path: String, expected: Image) -> void:
	var loaded := Image.load_from_file(ProjectSettings.globalize_path(path))
	assert_not_null(loaded, "%s loads" % path)
	if loaded == null:
		return
	loaded.convert(Image.FORMAT_RGBA8)
	assert_eq(loaded.get_size(), expected.get_size())
	assert_eq(
		loaded.get_data(), expected.get_data(), "%s is stale; rerun tools/glyph_atlas.gd" % path
	)


func test_committed_luma_png_is_current() -> void:
	_assert_matches_file(Atlas.LUMA_PATH, Atlas.build_luma_atlas())


func test_committed_edge_png_is_current() -> void:
	_assert_matches_file(Atlas.EDGE_PATH, Atlas.build_edge_atlas())
