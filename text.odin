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
	// Metrics
	offset:      [2]f32,
	size:        [2]f32,
	// Occupied range in string indices
	index_range: [2]int,
	// Range of glyph
	glyph_range: [2]int,
}

Text_Layout :: struct {
	font:            Font,
	font_scale:      f32,
	// Layout objects
	glyphs:          []Text_Glyph,
	lines:           []Text_Line,
	// Layout size excluding descent
	size:            [2]f32,
	// Actual space occupied by displayed glyphs
	display_size:    [2]f32,
	// Selection range
	glyph_selection: [2]int,
	// Interaction results
	mouse_index:     int,
	hovered_glyph:   int,
	hovered_line:    int,
}

Text_Iterator :: struct {
	// Text parameters
	text:       string,
	options:    Text_Options,
	font:       Font,
	size:       f32,
	// Current glyph
	glyph:      Font_Glyph,
	// Line width to wrap at
	max_width:  f32,
	max_height: f32,
	// Current line width
	line_width: f32,
	// Set to true if `char` is the first of a new line
	new_line:   bool,
	// Current glyph offset
	offset:     [2]f32,
	// Previous rune
	last_char:  rune,
	// Current rune
	char:       rune,
	// Starting index of the next word
	next_word:  int,
	// Codepoint indices
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
	max_height: Maybe(f32),
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
	iter.max_height = options.max_height.? or_else math.F32_MAX
	return
}

make_text_layout :: proc(
	text: string,
	font: Font,
	size: f32,
	options: Text_Options = {},
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
		glyph_range = {0 = first_glyph},
	}
	line_height := (font.ascend - font.descend) * iter.size

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

		dist := abs(iter.offset.x - mouse.x)
		if dist < closest {
			closest = dist
			hovered_rune = iter.index
		}

		if iter.new_line || at_end {
			current_line := len(core.text_lines) - first_line

			if at_end {
				layout.hovered_line = min(layout.hovered_line, current_line)
			}

			if current_line == layout.hovered_line {
				layout.mouse_index = hovered_rune
			}

			hovered_rune = -1
			closest = math.F32_MAX

			line.glyph_range[1] = len(core.text_glyphs)
			line.size = {iter.line_width, font.line_height * size}

			line_offset: [2]f32
			switch iter.options.justify {
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

			line.glyph_range -= first_glyph

			append(&core.text_lines, line)

			layout.size.x = max(layout.size.x, line.size.x)
			layout.size.y += iter.font.line_height * iter.size

			line = Text_Line {
				glyph_range = {0 = line.glyph_range[1]},
				offset = iter.offset,
			}
		}

		if selection, ok := selection.?; ok {
			if selection[0] == iter.index {
				layout.glyph_selection[0] = len(core.text_glyphs) - first_glyph
			}
			if selection[1] == iter.index {
				layout.glyph_selection[1] = len(core.text_glyphs) - first_glyph
			}
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

set_fallback_font :: proc(font: Font) {
	core.fallback_font = font
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
			it.glyph, ok = get_font_glyph(core.fallback_font.?, r)
		}
	}
	return true
}

iterate_text :: proc(iter: ^Text_Iterator) -> (ok: bool) {

	if iter.new_line {
		iter.line_width = 0
	}

	// Advance glyph position
	if iter.char != 0 {
		iter.offset.x += iter.glyph.advance * iter.size + iter.options.spacing
	}

	// Get the next glyph
	ok = iterate_text_rune(iter)

	// Get the current glyph's advance
	advance := iter.glyph.advance * iter.size

	// Space needed to fit this glyph/word
	space := advance
	if !ok {
		// We might need to use the end index
		iter.index = iter.next_index
		iter.char = 0
		iter.glyph = {}
	} else if (iter.options.wrap == .Word) &&
	   (iter.next_index >= iter.next_word) &&
	   (iter.char != ' ') {
		for i := iter.next_word; true; {
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

	// Reset new line state
	iter.new_line = false
	// If the last rune was '\n' then this is a new line
	if (iter.last_char == '\n') {
		iter.new_line = true
	} else {
		// Or if this rune would exceede the limit
		if iter.line_width + space > iter.max_width {
			if iter.options.wrap == .None {
				iter.char = 0
				ok = false
			} else {
				iter.new_line = true
			}
		}
	}

	if iter.new_line {
		iter.offset.x = 0
		iter.offset.y += iter.font.line_height * iter.size
		if iter.offset.y > iter.max_height {
			ok = false
		}
	}

	iter.line_width += iter.glyph.advance * iter.size
	if ok {
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

// A sort of gamma correction for text drawn in SRGB color space
// TODO: Maybe move this to the GPU?
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
	font: Font = DEFAULT_FONT,
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
	// origin := origin + {0, glyph.descend * size}
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
