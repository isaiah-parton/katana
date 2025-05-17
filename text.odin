package katana

import "base:intrinsics"
import "core:fmt"
import "core:io"
import "core:math"
import "core:math/linalg"
import "core:mem"
import "core:slice"
import "core:strings"
import "core:unicode"
import "core:unicode/utf8"

Text_Justify :: enum {
	Left,
	Center,
	Right,
}

Text_Wrap :: enum {
	None,
	Words,
	Runes,
}

Text_Glyph :: struct {
	using glyph: Font_Glyph,
	offset:      [2]f32,
	code:        rune,
	index:       int,
	line:        int,
}

Text_Line :: struct {
	offset:      [2]f32,
	size:        [2]f32,
	first_glyph: int,
	last_glyph:  int,
}

Text :: struct {
	font:       Font,
	font_scale: f32,
	glyphs:     []Text_Glyph,
	lines:      []Text_Line,
	size:       [2]f32,
}

Text_Point_Contact :: struct {
	valid: bool,
	index: int,
	line:  int,
	glyph: int,
}

Text_Selection :: struct {
	glyphs: [2]int,
	lines:  [2]int,
}

Selectable_Text :: struct {
	using text: Text,
	contact:    Text_Point_Contact,
	selection:  Text_Selection,
}

Text_Builder :: struct {
	reader:          io.Reader,
	font:            Font,
	glyph:           Font_Glyph,
	line:            Text_Line,
	offset:          [2]f32,
	size:            [2]f32,
	// Index of last glyph to wrap when overflow happens
	wrap_to_glyph:   int,
	index:           int,
	next_index:      int,
	font_size:       f32,
	spacing:         f32,
	max_width:       f32,
	max_height:      f32,
	justify:         f32,
	last_char:       rune,
	char:            rune,
	is_white_space:  bool,
	was_white_space: bool,
	at_end:          bool,
	wrap:            Text_Wrap,
	glyphs:          [dynamic]Text_Glyph,
	lines:           [dynamic]Text_Line,
}

text_is_empty :: proc(text: ^Text) -> bool {
	return len(text.glyphs) == 0
}

make_text :: proc(
	s: string,
	size: f32,
	font: Font = core.current_font,
	wrap: Text_Wrap = .None,
	justify: f32 = 0,
	max_size: [2]f32 = math.F32_MAX,
	allocator: mem.Allocator = context.temp_allocator,
) -> (
	text: Text,
) {
	reader: strings.Reader
	text = make_text_with_reader(
		strings.to_reader(&reader, s),
		size,
		font,
		wrap,
		justify,
		max_size,
		allocator,
	)
	return
}

make_text_with_reader :: proc(
	reader: io.Reader,
	size: f32,
	font: Font = core.current_font,
	wrap: Text_Wrap = .None,
	justify: f32 = 0,
	max_size: [2]f32 = math.F32_MAX,
	allocator: mem.Allocator = context.temp_allocator,
) -> (
	text: Text,
) {
	b := Text_Builder {
		font       = font,
		font_size  = size,
		reader     = reader,
		max_width  = max_size.x,
		max_height = max_size.y,
		wrap       = wrap,
		glyphs     = make([dynamic]Text_Glyph, len = 0, cap = 64, allocator = allocator),
		lines      = make([dynamic]Text_Line, len = 0, cap = 16, allocator = allocator),
	}

	text.font_scale = size

	// Move the last word down one line
	wrap_last_word :: proc(b: ^Text_Builder) {
		move_left := b.glyphs[b.wrap_to_glyph].offset.x
		if move_left == 0 {
			return
		}
		descent := b.font.line_height * b.font_size
		word_width: f32
		for &glyph in b.glyphs[b.wrap_to_glyph:] {
			glyph.offset.x -= move_left
			glyph.offset.y += descent
			glyph.line += 1
		}
		for &glyph in b.glyphs[b.wrap_to_glyph:len(b.glyphs) - 1] {
			word_width += glyph.advance * b.font_size + b.spacing
		}
		b.offset.x += word_width
		b.line.size.x += word_width
	}

	// Start a new line, but don't add it
	start_line_on_glyph :: proc(b: ^Text_Builder, index: int) {
		b.offset.y += b.font.line_height * b.font_size
		b.line = Text_Line {
			first_glyph = index,
			offset      = b.offset,
		}
	}

	// End the current line, adding it to the array
	end_line_on_glyph :: proc(b: ^Text_Builder, index: int, loc := #caller_location) {
		if index < 0 {
			return
		}
		b.line.last_glyph = index
		glyph := b.glyphs[index]
		b.line.size = {
			glyph.offset.x + glyph.advance * b.font_size,
			b.font.line_height * b.font_size,
		}
		line_offset := b.line.size.x * -b.justify

		for &glyph in b.glyphs[b.line.first_glyph:index] {
			glyph.offset.x += line_offset
		}
		b.line.offset.x += line_offset

		b.offset.x = 0

		b.size.x = max(b.size.x, b.line.size.x)
		b.size.y += b.font.line_height * b.font_size
		append(&b.lines, b.line)
	}

	next_glyph_index: int = -1

	for !b.at_end {
		if b.offset.y >= b.max_height {
			// end_line_on_glyph(&b, len(b.glyphs) - 1)
			break
		}

		b.index = b.next_index

		if b.char != 0 {
			b.offset.x += b.glyph.advance * b.font_size + b.spacing
		}

		err: io.Error

		b.last_char = b.char
		b.char, _, err = io.read_rune(b.reader, &b.next_index)

		glyph_found: bool
		b.was_white_space = b.is_white_space
		if err == .EOF {
			b.at_end = true
			b.glyph = {}
			b.char = 0
			b.is_white_space = true
		} else if b.char == '\t' {
			b.glyph = {
				advance = b.font.space_advance * 2,
			}
			b.is_white_space = true
		} else {
			b.glyph, glyph_found = find_font_glyph(b.font, b.char)
			b.is_white_space = unicode.is_white_space(b.char)
		}

		next_glyph_index += append(
			&b.glyphs,
			Text_Glyph {
				line = len(b.lines),
				glyph = b.glyph,
				code = b.char,
				index = b.index,
				offset = b.offset,
			},
		)

		b.line.size.x += b.glyph.advance * b.font_size + b.spacing * f32(i32(!b.at_end))

		if b.wrap == .Words {
			if b.is_white_space {
				if !b.was_white_space && b.line.size.x > b.max_width && b.wrap_to_glyph > 0 {
					end_line_on_glyph(&b, b.wrap_to_glyph - 1)
					start_line_on_glyph(&b, b.wrap_to_glyph)
					wrap_last_word(&b)
					if b.offset.y >= b.max_height {
						end_line_on_glyph(&b, next_glyph_index)
						break
					}
				}
			} else if b.was_white_space {
				b.wrap_to_glyph = next_glyph_index
			}
		}

		if b.char == '\n' {
			if b.last_char != 0 {
				end_line_on_glyph(&b, next_glyph_index)
				start_line_on_glyph(&b, next_glyph_index + 1)
			}
		} else if b.at_end {
			end_line_on_glyph(&b, next_glyph_index)
		}
	}

	text.glyphs = b.glyphs[:]
	text.lines = b.lines[:]
	text.size = b.size
	text.font_scale = size
	text.font = font

	return
}

make_selectable :: proc(text: Text, point: [2]f32, selection: [2]int) -> Selectable_Text {
	text := Selectable_Text {
		text = text,
	}

	if len(text.glyphs) == 0 {
		return text
	}

	closest: f32 = math.F32_MAX

	text.contact.line = max(
		min(int(point.y / f32(text.font.line_height * text.font_scale)), len(text.lines) - 1),
		0,
	)

	for &line, line_index in text.lines {
		line_box := Box{line.offset, line.offset + line.size}
		if point.x >= line_box.lo.x &&
		   point.x < line_box.hi.x &&
		   point.y >= line_box.lo.y &&
		   point.y < line_box.hi.y {
			text.contact.valid = true
			break
		}
	}

	for &glyph, glyph_index in text.glyphs {
		if glyph.index == selection[0] {
			text.selection.glyphs[0] = glyph_index
			text.selection.lines[0] = glyph.line
		}
		if glyph.index == selection[1] {
			text.selection.glyphs[1] = glyph_index
			text.selection.lines[1] = glyph.line
		}
	}

	line := &text.lines[text.contact.line]
	for &glyph, glyph_index in text.glyphs[line.first_glyph:line.last_glyph + 1] {
		distance := abs(glyph.offset.x - point.x)
		if distance < closest {
			closest = distance
			text.contact.index = glyph.index
			text.contact.glyph = glyph_index
		}
	}

	return text
}

find_font_glyph :: proc(font: Font, char: rune) -> (glyph: Font_Glyph, ok: bool) {
	glyph, ok = get_font_glyph(font, char)
	if !ok {
		glyph, ok = get_font_glyph(core.fallback_font, char)
	}
	return
}

@(private)
closest_line_of_text :: proc(offset, text_height, line_height: f32) -> Maybe(int) {
	line_count := int(math.floor(text_height / line_height))
	mouse_line := int(offset / line_height)
	return mouse_line if (mouse_line >= 0 && mouse_line < line_count) else nil
}

// FIXME: If `paint` is not an existing paint then it will be duplicated for every glyph
add_text :: proc(text: Text, origin: [2]f32, paint: Paint_Option = nil) {
	paint_index := paint_index_from_option(paint)
	for &glyph in text.glyphs {
		if glyph.source.lo == glyph.source.hi {
			continue
		}
		add_glyph(glyph, text.font_scale, origin + glyph.offset, paint = paint_index)
	}
}

add_text_range :: proc(text: Text, range: [2]int, origin: [2]f32, paint: Paint_Option = nil) {
	paint_index := paint_index_from_option(paint)
	for &glyph in text.glyphs[range[0]:max(range[0], range[1])] {
		add_glyph(
			glyph,
			text.font_scale,
			origin + glyph.offset,
			paint = paint_index,
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

add_string :: proc(
	str: string,
	size: f32,
	origin: [2]f32,
	align: [2]f32 = 0,
	justify: f32 = 0,
	paint: Paint_Option = nil,
) -> [2]f32 {
	text := make_text(str, size, font = core.current_font, justify = justify)
	add_text(text, origin - text.size * align, paint)
	return text.size
}

add_string_wrapped :: proc(
	str: string,
	size: f32,
	box: Box,
	align: [2]f32 = 0,
	paint: Paint_Option = nil,
) -> [2]f32 {
	text := make_text(
		str,
		size,
		font = core.current_font,
		max_size = box.hi - box.lo,
		wrap = .Words,
		justify = align.x,
	)
	add_text(text, math.lerp(box.lo, box.hi, align), paint)
	return text.size
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

add_rune :: proc(
	char: rune,
	size: f32,
	origin: [2]f32,
	align: [2]f32 = 0,
	font: Font = core.current_font,
	paint: Paint_Option = nil,
) -> u32 {
	glyph, ok := get_font_glyph(font, char)
	if !ok {
		return 0
	}
	return add_glyph(
		glyph,
		size,
		origin - {glyph.advance, font.line_height} * align * size,
		paint = paint,
	)
}

add_glyph :: proc(
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

add_text_scaffold :: proc(text: Text, origin: [2]f32) {
	for &line in text.lines {
		add_box_lines({origin + line.offset, origin + line.offset + line.size}, 1, paint = RED)
	}
}

