package vgo

import "core:fmt"
import "core:math"
import "core:math/linalg"

Text_Glyph :: struct {
	using glyph: Font_Glyph,
	offset: [2]f32,
}

Text_Line :: struct {
	first, last: int,
	offset: [2]f32,
	size: [2]f32,
}

Text :: struct {
	glyphs: []Text_Glyph,
	size: [2]f32,
}

make_text :: proc(content: string, font: Font, size: f32, line_limit: f32 = math.F32_MAX) -> Text {
	result: Text

	offset: [2]f32

	for r in content {
		glyph := get_font_glyph(font, r) or_continue
		if offset.x + glyph.advance > line_limit {
			offset.x = 0
			offset.y += font.line_height * size
		}
	}

	return result
}

measure_text :: proc(text: string, font: Font, size: f32, line_limit: f32 = math.F32_MAX) -> [2]f32 {
	text_size: [2]f32
	size := size / font.ascend
	text_size.y += font.descend * size
	line_height := font.line_height * size
	for r in text {
		if r == '\n' {
			text_size.x = 0
			text_size.y += line_height
		}
		glyph := get_font_glyph(font, r) or_continue
		advance := glyph.advance * size
		if text_size.x + advance > line_limit {
			text_size.x = 0
			text_size.y += line_height
		}
		text_size.x += advance
	}
	text_size.y += line_height
	return text_size
}

fill_text :: proc(text: string, font: Font, origin: [2]f32, size: f32, paint: Paint_Option, line_limit: f32 = math.F32_MAX) -> [2]f32 {
	offset: [2]f32
	size := size / font.ascend
	offset.y += font.descend * size
	line_height := font.line_height * size
	for r in text {
		if r == '\n' {
			offset.x = 0
			offset.y += line_height
		}

		glyph := get_font_glyph(font, r) or_continue
		advance := glyph.advance * size
		if offset.x + advance > line_limit {
			offset.x = 0
			offset.y += line_height
		}
		draw_glyph(font, glyph, origin + offset, size, paint)
		offset.x += advance
	}
	offset.y += line_height
	return offset
}

draw_glyph :: proc(
	font: Font,
	glyph: Font_Glyph,
	origin: [2]f32,
	size: f32,
	paint: Paint_Option,
) {
	shape_index := add_shape(
		Shape {
			kind = .Glyph,
			radius = max(font.distance_range, (size / font.size) * font.distance_range),
		},
	)
	vertex_color := paint.(Color) or_else 255
	paint_index := paint_index_from_option(paint)
	a := add_vertex(
		Vertex {
			pos = origin + glyph.bounds.lo * size,
			uv = glyph.source.lo / core.atlas_size,
			col = vertex_color,
			shape = shape_index,
			paint = paint_index,
		},
	)
	b := add_vertex(
		Vertex {
			pos = origin + {glyph.bounds.hi.x, glyph.bounds.lo.y} * size,
			uv = [2]f32{glyph.source.hi.x, glyph.source.lo.y} / core.atlas_size,
			col = vertex_color,
			shape = shape_index,
			paint = paint_index,
		},
	)
	c := add_vertex(
		Vertex {
			pos = origin + glyph.bounds.hi * size,
			uv = glyph.source.hi / core.atlas_size,
			col = vertex_color,
			shape = shape_index,
			paint = paint_index,
		},
	)
	d := add_vertex(
		Vertex {
			pos = origin + {glyph.bounds.lo.x, glyph.bounds.hi.y} * size,
			uv = [2]f32{glyph.source.lo.x, glyph.source.hi.y} / core.atlas_size,
			col = vertex_color,
			shape = shape_index,
			paint = paint_index,
		},
	)
	add_indices(a, b, c, a, c, d)
}
