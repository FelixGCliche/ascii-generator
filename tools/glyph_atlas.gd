class_name GlyphAtlas
extends SceneTree
## Generates the glyph atlases sampled by the tile shaders.
##
## Run with: godot --headless -s tools/glyph_atlas.gd
##
## Glyphs are hand-authored 8x8 1-bit bitmaps (no font rendering), so output is
## deterministic and works headless. Atlases are RGBA8, opaque, white glyph pixels
## on black; shaders sample the `.r` channel.
##
## IMPORTANT: shaders must sample these textures with `filter_nearest` (and no
## mipmaps), otherwise the pixel glyphs blur.
##
## Luma atlas (80x8): 10 cells in one row, darkest to brightest:
##   ' ' '.' ':' '-' '=' '+' '*' '#' '%' '@'
## Edge atlas (32x8): 4 cells in one row. Index to direction mapping:
##   0 '|' vertical, 1 '_' horizontal, 2 '/' diagonal-up, 3 '\' diagonal-down

const CELL_SIZE := 8
const LUMA_LEVELS := 10
const EDGE_GLYPHS := 4
const LUMA_PATH := "res://src/glyphs/glyphs_luma.png"
const EDGE_PATH := "res://src/glyphs/glyphs_edge.png"

# Each glyph is 8 rows of 8 chars; '#' is lit, '.' is dark.
const LUMA_GLYPHS: Array = [
	# ' '
	[
		"........",
		"........",
		"........",
		"........",
		"........",
		"........",
		"........",
		"........"
	],
	# '.'
	[
		"........",
		"........",
		"........",
		"........",
		"........",
		"...##...",
		"...##...",
		"........"
	],
	# ':'
	[
		"........",
		"...##...",
		"...##...",
		"........",
		"........",
		"...##...",
		"...##...",
		"........"
	],
	# '-'
	[
		"........",
		"........",
		"........",
		".######.",
		"..####..",
		"........",
		"........",
		"........"
	],
	# '='
	[
		"........",
		"########",
		"........",
		"........",
		"........",
		"........",
		"########",
		"........"
	],
	# '+'
	[
		"...##...",
		"...##...",
		"...##...",
		"########",
		"########",
		"...##...",
		"...##...",
		"...##..."
	],
	# '*'
	[
		"...##...",
		"#.####.#",
		".######.",
		"..####..",
		"..####..",
		".######.",
		"#.####.#",
		"...##..."
	],
	# '#'
	[
		".##..##.",
		"########",
		".##..##.",
		".##..##.",
		"########",
		".##..##.",
		".##..##.",
		".##..##."
	],
	# '%'
	[
		"########",
		"##.##.##",
		"########",
		"##.##.##",
		"########",
		"##.##.##",
		"########",
		"........"
	],
	# '@'
	[
		".######.",
		"########",
		"###.####",
		"###.####",
		"###.####",
		"########",
		"########",
		".######."
	],
]

const EDGE_BITMAPS: Array = [
	# '|'
	[
		"...##...",
		"...##...",
		"...##...",
		"...##...",
		"...##...",
		"...##...",
		"...##...",
		"...##..."
	],
	# '_'
	[
		"........",
		"........",
		"........",
		"........",
		"........",
		"........",
		"........",
		"########"
	],
	# '/'
	[
		"......##",
		".....##.",
		"....##..",
		"...##...",
		"..##....",
		".##.....",
		"##......",
		"#......."
	],
	# '\'
	[
		"##......",
		".##.....",
		"..##....",
		"...##...",
		"....##..",
		".....##.",
		"......##",
		".......#"
	],
]


static func build_luma_atlas() -> Image:
	return _build_atlas(LUMA_GLYPHS)


static func build_edge_atlas() -> Image:
	return _build_atlas(EDGE_BITMAPS)


static func cell_rect(index: int) -> Rect2i:
	return Rect2i(index * CELL_SIZE, 0, CELL_SIZE, CELL_SIZE)


static func lit_pixel_count(image: Image, index: int) -> int:
	var rect := cell_rect(index)
	var count := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if image.get_pixel(x, y).r > 0.5:
				count += 1
	return count


static func _build_atlas(glyphs: Array) -> Image:
	var image := Image.create(CELL_SIZE * glyphs.size(), CELL_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLACK)
	for index in glyphs.size():
		var rows: Array = glyphs[index]
		for y in CELL_SIZE:
			for x in CELL_SIZE:
				if rows[y][x] == "#":
					image.set_pixel(index * CELL_SIZE + x, y, Color.WHITE)
	return image


func _initialize() -> void:
	var failed := false
	var targets := {LUMA_PATH: build_luma_atlas(), EDGE_PATH: build_edge_atlas()}
	for path: String in targets:
		var absolute := ProjectSettings.globalize_path(path)
		DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
		var err: int = (targets[path] as Image).save_png(absolute)
		if err != OK:
			push_error("Failed to save %s (error %d)" % [path, err])
			failed = true
	quit(1 if failed else 0)
