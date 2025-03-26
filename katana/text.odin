package katana

import "base:intrinsics"
import "core:fmt"
import "core:io"
import "core:math"
import "core:math/linalg"
import "core:mem"
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

@(init)
asdf :: proc() {
	fmt.println(size_of(Text_Glyph))
}

Text_Line :: struct {
	offset:      [2]f32,
	size:        [2]f32,
	first_glyph: int,
	last_glyph:  int,
}

Text :: struct {
	font:             Font,
	font_scale:       f32,
	glyphs:           []Text_Glyph,
	lines:            []Text_Line,
	size:             [2]f32,
	selection_lines:  [2]int,
	selection_glyphs: [2]int,
}

Text_Selection :: struct {
	valid: bool,
	index: int,
	line:  int,
	glyph: int,
}

Selectable_Text :: struct {
	using text: Text,
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
	selection: Maybe([2]int) = nil,
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
		selection,
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
	selection: Maybe([2]int) = nil,
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
		lines      = make([dynamic]Text_Line, len = 0, cap = 8, allocator = allocator),
	}

	text.font_scale = size

	wrap_to_last_word :: proc(b: ^Text_Builder) {
		move_left := b.glyphs[b.wrap_to_glyph].offset.x
		if move_left == 0 {
			return
		}
		descent := b.font.line_height * b.font_size
		word_width: f32
		for &glyph in b.glyphs[b.wrap_to_glyph:] {
			glyph.offset.x -= move_left
			glyph.offset.y += descent
			word_width += glyph.advance * b.font_size
		}
		b.offset.x += word_width
		b.line.size.x += word_width
	}

	end_line_on_glyph :: proc(b: ^Text_Builder, index: int) {
		b.line.last_glyph = index
		b.line.size = {b.glyphs[index].offset.x, b.font.line_height * b.font_size}
		line_offset := b.line.size.x * b.justify

		for &glyph in b.glyphs[b.line.first_glyph:index] {
			glyph.offset.x += line_offset
		}
		b.line.offset.x += line_offset

		b.offset.x = 0
		b.offset.y += b.font.line_height * b.font_size
		new_line := Text_Line {
			first_glyph = index,
			offset      = b.offset,
		}

		b.size.x = max(b.size.x, b.line.size.x)
		b.size.y += b.font.line_height * b.font_size
		append(&b.lines, b.line)

		b.line = new_line
	}

	for !b.at_end {
		if b.offset.y >= b.max_height {
			break
		}

		b.index = b.next_index

		if b.char != 0 {
			b.offset.x += b.glyph.advance * b.font_size + b.spacing
		}

		err: io.Error

		b.last_char = b.char
		b.char, _, err = io.read_rune(b.reader, &b.next_index)

		if err == .EOF {
			b.at_end = true
			b.glyph = {}
			b.char = 0
		} else {
			b.glyph, _ = find_font_glyph(b.font, b.char)
			b.was_white_space = b.is_white_space
			b.is_white_space = unicode.is_white_space(b.char)
		}

		next_glyph_index := len(b.glyphs)
		append(
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
			if b.is_white_space || b.at_end {
				if !b.was_white_space && b.line.size.x > b.max_width && b.wrap_to_glyph > 0 {
					end_line_on_glyph(&b, b.wrap_to_glyph)
					wrap_to_last_word(&b)
				}
			} else if b.was_white_space {
				b.wrap_to_glyph = next_glyph_index
			}
		}

		if b.char == '\n' || b.at_end {
			end_line_on_glyph(&b, next_glyph_index)
		}
	}

	text.glyphs = b.glyphs[:]
	text.lines = b.lines[:]
	text.size = b.size

	return
}

make_selectable :: proc(text: Text, point: [2]f32) -> Selectable_Text {
	text := Selectable_Text {
		text = text,
	}

	closest: f32 = math.F32_MAX

	text.selection.glyph = -1
	text.selection.line = clamp(
		int(point.y / (text.font.line_height * text.font_scale)),
		0,
		len(text.lines) - 1,
	)

	for &line, line_index in text.lines {
		line_box := Box{line.offset, line.offset + line.size}
		if point.x >= line_box.lo.x &&
		   point.x < line_box.hi.x &&
		   point.y >= line_box.lo.y &&
		   point.y < line_box.hi.y {
			text.selection.valid = true
		}
	}

	line := &text.lines[text.selection.line]
	for &glyph, glyph_index in text.glyphs[line.first_glyph:line.last_glyph + 1] {
		distance := abs(glyph.offset.x - point.x)
		if distance < closest {
			closest = distance
			text.selection.index = glyph.index
			text.selection.glyph = int(glyph_index)
		}
		// TODO: Remove
		// if glyph_index == len(text.glyphs) - 1 {
		// 	text.selection.line = min(text.selection.line, glyph.line)
		// }
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

add_text :: proc(text: Text, origin: [2]f32, paint: Paint_Option = nil) {
	for &glyph in text.glyphs {
		add_glyph(
			glyph,
			text.font_scale,
			origin + glyph.offset,
			paint = paint_index_from_option(paint),
			bias = glyph_bias_from_paint(paint),
		)
	}
}

add_text_range :: proc(text: Text, range: [2]int, origin: [2]f32, paint: Paint_Option = nil) {
	for &glyph in text.glyphs[range[0]:max(range[0], range[1])] {
		add_glyph(
			glyph,
			text.font_scale,
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
		fmt.printfln("Unable to find font glyph '%c'", char)
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
		add_box_lines({origin + line.offset, origin + line.offset + line.size}, 1, paint = Red)
	}
}

