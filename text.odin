package vgo

import "base:intrinsics"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:unicode"
import "core:unicode/utf8"

Text_Justify :: enum {
	Left,
	Center,
	Right,
}

Text_Wrap :: enum {
	None,
	Character,
	Word,
}

Text_Glyph :: struct {
	using glyph: Font_Glyph,
	code:        rune,
	index:       int,
	offset:      [2]f32,
}

Text_Line :: struct {
	offset:      [2]f32,
	size:        [2]f32,
	index_range: [2]int,
	glyph_range: [2]int,
}

Text_Layout :: struct {
	font:            Font,
	font_scale:      f32,
	glyphs:          []Text_Glyph,
	lines:           []Text_Line,
	size:            [2]f32,
	display_size:    [2]f32,
	glyph_selection: [2]int,
	mouse_index:     int,
	hovered_glyph:   int,
	hovered_line:    int,
}

Text_Iterator :: struct {
	glyph:      Font_Glyph,
	line_width: f32,
	new_line:   bool,
	at_end:     bool,
	offset:     [2]f32,
	last_char:  rune,
	char:       rune,
	next_word:  int,
	index:      int,
	next_index: int,
}

Text_Options :: struct {
	spacing:    f32,
	max_width:  f32,
	max_height: f32,
	wrap:       Text_Wrap,
	justify:    Text_Justify,
	obfuscated: bool,
}

DEFAULT_TEXT_OPTIONS :: Text_Options {
	spacing    = 0,
	max_width  = math.F32_MAX,
	max_height = math.F32_MAX,
	wrap       = .None,
	justify    = .Left,
}

// Argument defaults should be faster than checking a `Maybe()`
text_options :: proc(
	spacing: f32 = DEFAULT_TEXT_OPTIONS.spacing,
	max_width: f32 = DEFAULT_TEXT_OPTIONS.max_width,
	max_height: f32 = DEFAULT_TEXT_OPTIONS.max_height,
	wrap: Text_Wrap = DEFAULT_TEXT_OPTIONS.wrap,
	justify: Text_Justify = DEFAULT_TEXT_OPTIONS.justify,
) -> Text_Options {
	return {
		spacing = spacing,
		max_width = max_width,
		max_height = max_height,
		wrap = wrap,
		justify = justify,
	}
}

text_layout_is_empty :: proc(layout: ^Text_Layout) -> bool {
	return len(layout.glyphs) == 0
}

make_text_layout :: proc(
	text: string,
	size: f32,
	font: Font = core.current_font,
	options: Text_Options = DEFAULT_TEXT_OPTIONS,
	local_mouse: [2]f32 = {},
	selection: Maybe([2]int) = nil,
) -> (
	layout: Text_Layout,
) {
	iter: Text_Iterator

	first_glyph := len(core.text_glyphs)
	first_line := len(core.text_lines)

	line: Text_Line = {
		glyph_range = {0 = first_glyph},
	}
	line_height := (font.ascend - font.descend) * size

	layout.hovered_glyph = -1
	layout.font_scale = size
	layout.font = font

	hovered_rune: int = -1
	closest: f32 = math.F32_MAX

	layout.hovered_line = max(0, int(local_mouse.y / line_height))

	for iterate_text(&iter, text, font, size, options) {

		dist := abs(iter.offset.x - local_mouse.x)
		if dist < closest {
			closest = dist
			hovered_rune = iter.index
		}

		if iter.new_line || iter.at_end {
			current_line := len(core.text_lines) - first_line

			if iter.at_end {
				layout.hovered_line = min(layout.hovered_line, current_line)
			}

			if current_line == layout.hovered_line {
				layout.mouse_index = hovered_rune
			}

			hovered_rune = -1
			closest = math.F32_MAX

			line.glyph_range[1] = len(core.text_glyphs) - int(iter.new_line)
			line.size = {iter.line_width, font.line_height * size}
			line_offset: [2]f32

			switch options.justify {
			case .Left:
			case .Center:
				line_offset.x = -line.size.x / 2
			case .Right:
				line_offset.x = -line.size.x
			}

			for &glyph in core.text_glyphs[line.glyph_range[0]:line.glyph_range[1]] {
				glyph.offset += line_offset
			}
			line.offset += line_offset

			new_line := Text_Line {
				glyph_range = {0 = len(core.text_glyphs)},
				offset = iter.offset,
			}

			line.glyph_range -= first_glyph
			layout.size.x = max(layout.size.x, line.size.x)
			layout.size.y += font.line_height * size
			append(&core.text_lines, line)

			line = new_line
		}


		if selection, ok := selection.?; ok {
			local_glyph_index := len(core.text_glyphs) - first_glyph
			if selection[0] == iter.index do layout.glyph_selection[0] = local_glyph_index
			if selection[1] == iter.index do layout.glyph_selection[1] = local_glyph_index
		}

		if iter.at_end {
			iter.glyph = {}
			iter.char = 0
		}

		// Add a glyph last so that `len(core.text_glyphs)` is the index of this glyph
		append(
			&core.text_glyphs,
			Text_Glyph {
				glyph = iter.glyph,
				code = iter.char,
				index = iter.index,
				offset = iter.offset,
			},
		)
	}

	layout.glyphs = core.text_glyphs[first_glyph:]
	layout.lines = core.text_lines[first_line:]

	layout.hovered_line =
		closest_line_of_text(local_mouse.y, layout.size.y, line_height).? or_else -1

	return
}

find_font_glyph :: proc(font: Font, char: rune) -> Font_Glyph {
	glyph: Font_Glyph
	ok: bool
	glyph, ok = get_font_glyph(font, char)
	if !ok && char > unicode.MAX_LATIN1 && core.fallback_font != nil {
		glyph, ok = get_font_glyph(core.fallback_font.?, char)
	}
	return glyph
}

@(private)
closest_line_of_text :: proc(offset, layout_height, line_height: f32) -> Maybe(int) {
	line_count := int(math.floor(layout_height / line_height))
	hovered_line := int(offset / line_height)
	return hovered_line if (hovered_line >= 0 && hovered_line < line_count) else nil
}

@(private)
first_word_in :: proc(
	text: string,
	font: Font,
	size: f32,
	spacing: f32,
) -> (
	end: int,
	width: f32,
) {
	for i := 0; true; {
		char, bytes := utf8.decode_rune(text[i:])
		if char != '\n' {
			if glyph, ok := get_font_glyph(font, char); ok {
				width += glyph.advance * size + spacing
			}
		}
		if char == ' ' || i > len(text) - 1 {
			end = i + bytes
			break
		}
		i += bytes
	}
	return
}

@(private)
iterate_text :: proc(
	iter: ^Text_Iterator,
	text: string,
	font: Font,
	size: f32,
	options: Text_Options = DEFAULT_TEXT_OPTIONS,
) -> bool {
	iter := iter

	if iter.at_end {
		return false
	}

	if iter.new_line {
		iter.line_width = 0
		iter.line_width += iter.glyph.advance * size + options.spacing
	}

	if iter.char != 0 {
		iter.offset.x += iter.glyph.advance * size + options.spacing
	}

	iter.last_char = iter.char
	if iter.next_index >= len(text) {
		iter.at_end = true
	}
	iter.index = iter.next_index
	bytes: int
	iter.char, bytes = utf8.decode_rune(text[iter.index:])
	if options.obfuscated {
		iter.char = '*'
	}
	iter.next_index += bytes
	iter.glyph = find_font_glyph(font, iter.char)

	space := iter.glyph.advance * size

	if iter.at_end {
		iter.index = iter.next_index
		iter.char = 0
		iter.glyph = {}
	} else if (options.wrap == .Word) && (iter.index >= iter.next_word) && (iter.char != ' ') {
		iter.next_word, space = first_word_in(text[iter.index:], font, size, options.spacing)
	}

	iter.new_line = false

	if iter.last_char == '\n' {
		iter.new_line = true
	}
	if !iter.new_line {
		if iter.line_width + space > options.max_width {
			if options.wrap == .None {
				iter.at_end = true
			} else {
				iter.new_line = true
			}
		}
	}

	if iter.new_line {
		iter.offset.x = 0
		iter.offset.y += font.line_height * size
		if iter.offset.y > options.max_height {
			iter.at_end = true
		}
	} else {
		iter.line_width += iter.glyph.advance * size
		if !iter.at_end {
			iter.line_width += options.spacing
		}
	}

	return true
}

measure_text :: proc(
	text: string,
	font: Font,
	size: f32,
	options: Text_Options = DEFAULT_TEXT_OPTIONS,
) -> [2]f32 {
	return make_text_layout(text, size, font, options).size
}

fill_text_layout :: proc(
	layout: Text_Layout,
	origin: [2]f32,
	align: [2]f32 = 0,
	paint: Paint_Option = nil,
) {
	origin := origin - layout.size * align
	for &glyph in layout.glyphs {
		fill_glyph(
			glyph,
			layout.font_scale,
			origin + glyph.offset,
			paint = paint_index_from_option(paint),
			bias = glyph_bias_from_paint(paint),
		)
	}
}

// A sort of gamma correction for text drawn in SRGB color space
glyph_bias_from_paint :: proc(paint: Paint_Option) -> f32 {
	if core.renderer.surface_config.format != .RGBA8UnormSrgb &&
	   core.renderer.surface_config.format != .BGRA8UnormSrgb {
		return 0.0
	}
	if color, ok := paint.(Color); ok {
		return 0.5 - luminance_of(color) * 0.5
	}
	return 0.0
}

fill_text :: proc(
	text: string,
	size: f32,
	origin: [2]f32,
	font: Font = core.current_font,
	align: [2]f32 = 0,
	options: Text_Options = DEFAULT_TEXT_OPTIONS,
	paint: Paint_Option = nil,
) -> [2]f32 {
	layout := make_text_layout(text, size, font = font, options = options)
	fill_text_layout(layout, origin, align, paint)
	return layout.size
}

make_glyph :: proc(glyph: Font_Glyph, size: f32, origin: [2]f32, bias: f32 = 0) -> Shape {
	return Shape {
		kind = .Glyph,
		tex_min = glyph.source.lo / core.atlas_size,
		tex_max = glyph.source.hi / core.atlas_size,
		quad_min = origin + glyph.bounds.lo * size,
		quad_max = origin + glyph.bounds.hi * size,
		radius = {0 = bias},
	}
}

fill_glyph :: proc(
	glyph: Font_Glyph,
	size: f32,
	origin: [2]f32,
	paint: Paint_Option = nil,
	bias: f32 = 0.0,
) -> u32 {
	shape := make_glyph(glyph, size, origin, bias)
	shape.paint = paint_index_from_option(paint)
	return add_shape(shape)
}

text_layout_scaffold :: proc(layout: Text_Layout, origin: [2]f32) {
	for line in layout.lines {
		stroke_box({origin + line.offset, origin + line.offset + line.size}, 1, paint = RED)
	}
}
