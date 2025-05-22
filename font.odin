package katana

import "base:runtime"
import "core:c/libc"
import "core:encoding/json"
import "core:fmt"
import "core:io"
import "core:os"
import "core:strconv"
import "core:unicode"
import "core:unicode/utf16"
import "core:unicode/utf8"
import stbi "vendor:stb/image"
import "vendor:wgpu"

Font_Glyph :: struct {
	// UV location in source texture
	source:  Box,
	bounds:  Box,
	advance: f32,
}

Font :: struct {
	first_rune:        rune,
	// em_size:               f32,
	size:              f32,
	space_advance:     f32,
	ascend:            f32,
	descend:           f32,
	// underline_y:           f32,
	// underline_width:       f32,
	line_height:       f32,
	distance_range:    f32,
	glyphs:            []Font_Glyph,
	placeholder_glyph: Font_Glyph,
}

destroy_font :: proc(font: ^Font) {
	delete(font.glyphs)
	font^ = {}
}

set_font :: proc(font: Font) {
	core.current_font = font
}

set_fallback_font :: proc(font: Font) {
	core.fallback_font = font
}

load_font_from_files :: proc(image_file, json_file: string) -> (font: Font, ok: bool) {
	image_data := os.read_entire_file(image_file) or_return
	defer delete(image_data)
	json_data := os.read_entire_file(json_file) or_return
	defer delete(json_data)
	return load_font_from_slices(image_data, json_data)
}

load_font_from_slices :: proc(
	image_data, json_data: []u8,
	center_y: bool = false,
) -> (
	font: Font,
	ok: bool,
) {
	width, height: libc.int
	bitmap_data := stbi.load_from_memory(
		raw_data(image_data),
		i32(len(image_data)),
		&width,
		&height,
		nil,
		4,
	)

	if bitmap_data == nil do return
	atlas_source := copy_image_to_atlas(bitmap_data, int(width), int(height))

	json_value, json_err := json.parse(json_data)
	defer json.destroy_value(json_value)

	if json_err != nil do return

	obj := json_value.(json.Object) or_return

	atlas_obj := obj["atlas"].(json.Object) or_return
	font.distance_range = f32(atlas_obj["distanceRange"].(json.Float) or_return)
	font.size = f32(atlas_obj["size"].(json.Float) or_return)

	metrics_obj := obj["metrics"].(json.Object) or_return
	// font.em_size = f32(metrics_obj["emSize"].(json.Float) or_return)
	font.line_height = f32(metrics_obj["lineHeight"].(json.Float) or_return)
	font.ascend = f32(metrics_obj["ascender"].(json.Float) or_return)
	font.descend = f32(metrics_obj["descender"].(json.Float) or_return)
	// font.underline_y = f32(metrics_obj["underlineY"].(json.Float) or_return)
	// font.underline_width = f32(metrics_obj["underlineThickness"].(json.Float) or_return)

	glyphs: [dynamic]Font_Glyph

	for glyph_value, i in obj["glyphs"].(json.Array) or_return {
		glyph_obj := glyph_value.(json.Object) or_return
		code := rune(i32(glyph_obj["unicode"].(json.Float) or_return))
		glyph := Font_Glyph {
			advance = f32(glyph_obj["advance"].(json.Float) or_return),
		}
		// left, bottom, right, top
		if plane_bounds_obj, ok := glyph_obj["planeBounds"].(json.Object); ok {
			glyph.bounds = Box {
				{
					f32(plane_bounds_obj["left"].(json.Float) or_return),
					1.0 - f32(plane_bounds_obj["top"].(json.Float) or_return),
				},
				{
					f32(plane_bounds_obj["right"].(json.Float) or_return),
					1.0 - f32(plane_bounds_obj["bottom"].(json.Float) or_return),
				},
			}
		}
		if center_y {
			adjustment := font.line_height - font.ascend
			glyph.bounds.lo.y += adjustment
			glyph.bounds.hi.y += adjustment
		}
		if atlas_bounds_obj, ok := glyph_obj["atlasBounds"].(json.Object); ok {
			glyph.source = Box {
				{
					atlas_source.lo.x + f32(atlas_bounds_obj["left"].(json.Float) or_return),
					atlas_source.hi.y - f32(atlas_bounds_obj["top"].(json.Float) or_return),
				},
				{
					atlas_source.lo.x + f32(atlas_bounds_obj["right"].(json.Float) or_return),
					atlas_source.hi.y - f32(atlas_bounds_obj["bottom"].(json.Float) or_return),
				},
			}
		}
		if i == 0 {
			font.first_rune = code
		}
		index := int(code - font.first_rune)
		non_zero_resize(&glyphs, index + 1)
		glyphs[index] = glyph
	}
	font.glyphs = glyphs[:]
	ok = true

	if glyph, ok := get_font_glyph(&font, ' '); ok {
		font.space_advance = glyph.advance
	}

	// font.placeholder_glyph = get_font_glyph(font, '?') or_else Font_Glyph{}

	return
}

get_font_glyph :: proc(font: ^Font, char: rune) -> (glyph: Font_Glyph, ok: bool) {
	index := int(char - font.first_rune)
	ok = index >= 0 && index < len(font.glyphs)
	if !ok do return
	#no_bounds_check glyph = font.glyphs[index]
	return
}

font_glyph_size :: proc(glyph: Font_Glyph, scale: f32) -> [2]f32 {
	return (glyph.bounds.hi - glyph.bounds.lo) * scale
}

DEFAULT_FONT: Font

make_default_font :: proc() {
	ok: bool
	DEFAULT_FONT, ok = load_font_from_slices(DEFAULT_FONT_IMAGE, DEFAULT_FONT_JSON)
	if !ok {
		fmt.eprintln("Warning! Failed to load default font.")
	}
}

DEFAULT_FONT_IMAGE :: #load("font.png", []u8)
DEFAULT_FONT_JSON :: #load("font.json", []u8)
