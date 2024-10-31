package vgo

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
	// Rune
	code:        rune,
	// Encoded index
	index:       int,
	// Position relative to text origin
	offset:      [2]f32,
}

Text_Line :: struct {
	// Top left corner of line
	offset:      [2]f32,
	// Occupied range in text slice indices
	index_range: [2]int,
	// Range of glyph
	glyph_range: [2]int,
	// Total size
	size:        [2]f32,
}

Text_Layout :: struct {
	font:            Font,
	font_scale:      f32,
	glyphs:          []Text_Glyph,
	lines:           []Text_Line,
	size:            [2]f32,
	selection:       [2]int,
	glyph_selection: [2]int,
	// Interaction results
	mouse_index:     int,
	hovered_glyph:   int,
	hovered_line:    int,
}

Text_Iterator :: struct {
	text:       string,
	options:    Text_Options,
	font:       Font,
	size:       f32,
	glyph:      Font_Glyph,
	max_width:  f32,
	line_width: f32,
	// Set to true if `char` is the first of a new line
	new_line:   bool,
	offset:     [2]f32,
	last_char:  rune,
	char:       rune,
	next_word:  int,
	index:      int,
	next_index: int,
}

Text_Align_X :: enum {
	Left,
	Center,
	Right,
}

Text_Align_Y :: enum {
	Top,
	Center,
	Baseline,
	Bottom,
}

Text_Options :: struct {
	spacing:   f32,
	max_width: Maybe(f32),
	max_lines: Maybe(int),
	wrap:      Text_Wrap,
	justify:   Text_Justify,
	hidden:    bool,
}

make_text_iterator :: proc(
	text: string,
	font: Font,
	size: f32,
	options: Text_Options,
) -> (
	iter: Text_Iterator,
) {
	iter.text = text
	iter.font = font
	iter.size = size
	iter.options = options
	iter.options.spacing = max(0, iter.options.spacing)
	iter.max_width = options.max_width.? or_else math.F32_MAX
	return
}

make_text_layout :: proc(
	text: string,
	font: Font,
	size: f32,
	options: Text_Options = {},
	// Options for text interaction
	mouse: [2]f32 = {},
	selection: Maybe([2]int) = nil,
) -> (
	layout: Text_Layout,
) {
	iter := make_text_iterator(text, font, size, options)
	// Check glyph limit
	first_glyph := len(core.text_glyphs)
	first_line := len(core.text_lines)

	line: Text_Line = {
		offset = 0,
	}
	line_height := (font.ascend - font.descend) * iter.size

	layout.selection = -1
	layout.hovered_glyph = -1
	layout.font_scale = size
	layout.font = font

	hovered_rune: int = -1
	closest: f32 = math.F32_MAX

	layout.hovered_line = max(0, int(mouse.y / line_height))

	at_end: bool

	for {
		if !iterate_text(&iter) {
			at_end = true
		}

		// Figure out highlighting and cursor pos
		if selection, ok := selection.?; ok {
			if selection[0] == iter.index {
				layout.selection[0] = (len(core.text_glyphs) - first_glyph) - 1
				layout.glyph_selection[0] = len(core.text_glyphs) - first_glyph
			}
			if selection[1] == iter.index {
				layout.glyph_selection[1] = len(core.text_glyphs) - first_glyph
			}
			// lo, hi := min(selection[0], selection[1]), max(selection[0], selection[1])
		}

		// Add a glyph
		append(
			&core.text_glyphs,
			Text_Glyph {
				glyph = iter.glyph,
				code = iter.char,
				index = iter.index,
				offset = iter.offset,
			},
		)

		// Check for hovered index
		diff := abs(iter.offset.x - mouse.x)
		if diff < closest {
			closest = diff
			hovered_rune = iter.index
		}

		// Push a new line
		if iter.char == '\n' || at_end {
			current_line := len(core.text_lines) - first_line

			// Clamp hovered line index if this is the last one
			if at_end {
				layout.hovered_line = min(layout.hovered_line, current_line)
			}

			// Determine hovered rune
			if current_line == layout.hovered_line {
				layout.mouse_index = hovered_rune
			}

			// Reset glyph search
			hovered_rune = -1
			closest = math.F32_MAX

			// Determine line length in runes
			line.glyph_range[1] = len(core.text_glyphs) - first_glyph

			// Append a new line
			append(&core.text_lines, line)

			// Reset the current line
			line = Text_Line {
				glyph_range = len(core.text_glyphs) - first_glyph,
			}

			// Update text size
			layout.size.x = max(layout.size.x, iter.line_width)
			layout.size.y += line_height
		}

		if at_end {
			break
		}
	}

	// Take a slice of the global arrays
	layout.glyphs = core.text_glyphs[first_glyph:]
	layout.lines = core.text_lines[first_line:]

	// Figure out which line is hovered
	line_count := int(math.floor(layout.size.y / line_height))
	layout.hovered_line = int(mouse.y / line_height)
	if layout.hovered_line < 0 || layout.hovered_line >= line_count {
		layout.hovered_line = -1
	}

	return
}

iterate_text_rune :: proc(it: ^Text_Iterator) -> bool {
	it.last_char = it.char
	if it.next_index >= len(it.text) {
		return false
	}
	// Update index
	it.index = it.next_index
	// Decode next char
	bytes: int
	it.char, bytes = utf8.decode_rune(it.text[it.index:])
	// Update next index
	it.next_index += bytes
	// Get current glyph data
	if it.char == '\n' || it.char == '\r' {
		it.glyph = {}
	} else {
		r := '•' if it.options.hidden else it.char
		ok: bool
		it.glyph, ok = get_font_glyph(it.font, r)
		// Try fallback font
		if !ok && r > unicode.MAX_LATIN1 && core.fallback_font != nil {
			it.glyph, ok = get_font_glyph(core.fallback_font.?, it.char)
		}
	}
	return true
}

iterate_text :: proc(iter: ^Text_Iterator) -> (ok: bool) {

	advance := iter.glyph.advance * iter.size

	// Advance glyph position
	if iter.char != 0 {
		iter.offset.x += advance + iter.options.spacing
	}

	// Get the next glyph
	ok = iterate_text_rune(iter)

	// Space needed to fit this glyph/word
	space := advance
	if !ok {
		// We might need to use the end index
		iter.index = iter.next_index
		iter.char = 0
		iter.glyph = {}
	} else {
		// Get the space for the next word if needed
		if (iter.options.wrap == .Word) &&
		   (iter.next_index >= iter.next_word) &&
		   (iter.char != ' ') {
			for i := iter.next_word; true;  /**/{
				c, b := utf8.decode_rune(iter.text[i:])
				if c != '\n' {
					if g, ok := get_font_glyph(iter.font, iter.char); ok {
						space += g.advance * iter.size + iter.options.spacing
					}
				}
				if c == ' ' || i > len(iter.text) - 1 {
					iter.next_word = i + b
					break
				}
				i += b
			}
		}
	}

	// Reset new line state
	iter.new_line = false
	// If the last rune was '\n' then this is a new line
	if (iter.last_char == '\n') {
		iter.new_line = true
	} else {
		// Or if this rune would exceede the limit
		if (iter.line_width + space > iter.max_width) {
			if iter.options.wrap == .None {
				iter.char = 0
				ok = false
			} else {
				iter.new_line = true
			}
		}
	}

	// Update vertical offset if there's a new line or if reached end
	if iter.new_line {
		iter.line_width = 0
		switch iter.options.justify {
		case .Left:
			iter.offset.x = 0
		case .Center:
			iter.offset.x = -measure_next_line(iter^) / 2
		case .Right:
			iter.offset.x = -measure_next_line(iter^)
		}
		iter.offset.y += iter.font.line_height * iter.size
	}

	// Advance line width
	iter.line_width += advance
	if ok && iter.last_char != 0 {
		iter.line_width += iter.options.spacing
	}

	return
}

@(private)
measure_next_line :: proc(iter: Text_Iterator) -> f32 {
	iter := iter
	for iterate_text(&iter) {
		if iter.new_line {
			break
		}
	}
	return iter.line_width
}

@(private)
measure_next_word :: proc(iter: Text_Iterator) -> (size: f32, end: int) {
	iter := iter
	for iterate_text_rune(&iter) {
		size += iter.glyph.advance + iter.options.spacing
		if iter.char == ' ' {
			break
		}
	}
	end = iter.index
	return
}

measure_text :: proc(text: string, font: Font, size: f32, options: Text_Options = {}) -> [2]f32 {
	return make_text_layout(text, font, size, options).size
}

fill_text_layout :: proc(layout: Text_Layout, origin: [2]f32, paint: Paint_Option = nil) {
	// Determine optimal pixel range for antialiasing
	paint_index := paint_index_from_option(paint)
	bias := glyph_bias_from_paint(paint)
	// Draw the glyphs
	for &glyph in layout.glyphs {
		fill_glyph(
			glyph,
			layout.font_scale,
			origin + glyph.offset,
			paint = paint_index,
			bias = bias,
		)
	}
}

fill_text_layout_aligned :: proc(
	layout: Text_Layout,
	origin: [2]f32,
	align_x: Text_Align_X,
	align_y: Text_Align_Y,
	paint: Paint_Option = nil,
) {
	origin := origin
	// Determine optimal pixel range for antialiasing
	paint_index := paint_index_from_option(paint)
	bias := glyph_bias_from_paint(paint)

	switch align_x {
	case .Left:
	case .Center:
		origin.x -= layout.size.x / 2
	case .Right:
		origin.x -= layout.size.x
	}

	switch align_y {
	case .Top:
	case .Center:
		origin.y -= layout.size.y / 2
	case .Baseline:
		origin.y -= layout.font.ascend * layout.font_scale
	case .Bottom:
		origin.y -= layout.size.y
	}

	// Draw the glyphs
	for &glyph in layout.glyphs {
		fill_glyph(
			glyph,
			layout.font_scale,
			origin + glyph.offset,
			paint = paint_index,
			bias = bias,
		)
	}
}

glyph_bias_from_paint :: proc(paint: Paint_Option) -> f32 {
	if color, ok := paint.(Color); ok {
		return 0.5 - luminance_of(color) * 0.5
	}
	return 0.0
}

fill_text :: proc(
	text: string,
	font: Font,
	size: f32,
	origin: [2]f32,
	options: Text_Options = {},
	paint: Paint_Option = nil,
) -> [2]f32 {
	layout := make_text_layout(text, font, size, options)
	fill_text_layout(layout, origin, paint)
	return layout.size
}

fill_text_aligned :: proc(
	text: string,
	font: Font,
	size: f32,
	origin: [2]f32,
	align_x: Text_Align_X,
	align_y: Text_Align_Y,
	options: Text_Options = {},
	paint: Paint_Option = nil,
) -> [2]f32 {
	layout := make_text_layout(text, font, size, options)
	fill_text_layout_aligned(layout, origin, align_x, align_y, paint)
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
