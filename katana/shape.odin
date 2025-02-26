package katana

import "core:fmt"
import "core:math"
import "core:math/ease"
import "core:math/linalg"
import "core:time"

// These should be self-explanitory
Shape_Kind :: enum u32 {
	None,
	Circle,
	Box,
	Blurred_Box,
	Arc,
	Bezier,
	Pie,
	Path,
	Polygon,
	Glyph,
	Line_Segment,
	Signed_Bezier,
}

Shape_Outline :: enum u32 {
	None,
	Inner_Stroke,
	Stroke,
	Outer_Stroke,
	Glow,
}

// Operation for when shapes interact
Shape_Mode :: enum u32 {
	Union,
	Subtraction,
	Intersection,
	Xor,
}

// Shape data sent to the GPU
Shape :: struct #align (16) {
	kind:     Shape_Kind,
	next:     u32,
	quad_min: [2]f32,
	quad_max: [2]f32,
	tex_min:  [2]f32,
	tex_max:  [2]f32,
	cv0:      [2]f32,
	cv1:      [2]f32,
	cv2:      [2]f32,
	radius:   [4]f32,
	width:    f32,
	start:    u32,
	count:    u32,
	outline:  Shape_Outline,
	xform:    u32,
	paint:    Paint_Index,
	mode:     Shape_Mode,
}

Box :: struct {
	lo, hi: [2]f32,
}

box_bottom_left :: proc(box: Box) -> [2]f32 {
	return {box.lo.x, box.hi.y}
}

bot_top_right :: proc(box: Box) -> [2]f32 {
	return {box.hi.x, box.lo.y}
}

make_box :: proc(box: Box, radius: [4]f32 = {}) -> Shape {
	return Shape{kind = .Box, radius = radius, cv0 = box.lo, cv1 = box.hi}
}

make_circle :: proc(center: [2]f32, radius: f32) -> Shape {
	return Shape{kind = .Circle, cv0 = center, radius = radius}
}

make_arc :: proc(center: [2]f32, from, to, inner, outer: f32, squared: bool = false) -> Shape {
	from, to := from, to
	// be nice
	if from > to do from, to = to, from
	th0 := -(from + (to - from) * 0.5) + math.PI
	th1 := (to - from) / 2
	width := outer - inner
	return Shape {
		kind = .Arc,
		cv0 = center,
		cv1 = [2]f32{math.sin(th0), math.cos(th0)},
		cv2 = [2]f32{math.sin(th1), math.cos(th1)},
		start = u32(squared),
		radius = {0 = inner, 1 = width},
	}
}

make_pie :: proc(center: [2]f32, from, to, radius: f32) -> Shape {
	from, to := from, to
	for from > to do to += math.TAU
	th0 := -(from + (to - from) * 0.5) + math.PI
	th1 := (to - from) / 2
	return Shape {
		kind = .Pie,
		cv0 = center,
		cv1 = [2]f32{math.sin(th0), math.cos(th0)},
		cv2 = [2]f32{math.sin(th1), math.cos(th1)},
		radius = radius,
	}
}

// Link two or more shapes, so that each affects the next based on the provided `Shape_Mode`.
//
// Each nth shape affects the shape at n+1
//
// This can only be done to shapes that have not yet been added as they must all share the same transform.
add_linked_shapes :: proc(shapes: ..Shape, mode: Shape_Mode = .Union, paint: Paint_Option = nil) -> u32 {
	shape: Shape
	bounds := Box{math.F32_MAX, 0}
	for i := len(shapes) - 1; i > 0; i -= 1 {
		shape = shapes[i - 1]
		next_shape := shapes[i]
		next_shape.mode = mode
		shape.next = u32(len(core.renderer.shapes.data))
		append(&core.renderer.shapes.data, next_shape)
		if next_shape.mode != .Intersection {
			shape_bb := get_shape_bounding_box(next_shape)
			bounds.lo = linalg.min(bounds.lo, shape_bb.lo)
			bounds.hi = linalg.max(bounds.hi, shape_bb.hi)
		}
	}
	shape_bb := get_shape_bounding_box(shape)
	bounds.lo = linalg.min(bounds.lo, shape_bb.lo)
	bounds.hi = linalg.max(bounds.hi, shape_bb.hi)
	shape.quad_min = bounds.lo
	shape.quad_max = bounds.hi
	shape.paint = paint_index_from_option(paint)
	return add_shape(shape, true)
}

// Applies the current transform matrix and scissor, then queues the shape to
// be sent to the GPU.
add_shape :: proc(shape: Shape, no_bounds: bool = false) -> u32 {
	shape := shape
	if !no_bounds {
		bounds := get_shape_bounding_box(shape)
		// Apply quad bounds
		shape.quad_min = bounds.lo
		shape.quad_max = bounds.hi
	}
	// Apply scissor
	if scissor, ok := current_scissor().?; ok {
		shape.next = scissor.shape
		// Determine overlap
		left := max(0, scissor.box.lo.x - shape.quad_min.x)
		top := max(0, scissor.box.lo.y - shape.quad_min.y)
		right := max(0, shape.quad_max.x - scissor.box.hi.x)
		bottom := max(0, shape.quad_max.y - scissor.box.hi.y)
		// Clip tex coords for glyphs
		if shape.kind == .Glyph {
			source_factor := (shape.tex_max - shape.tex_min) / (shape.quad_max - shape.quad_min)
			shape.tex_min.x += left * source_factor.x
			shape.tex_min.y += top * source_factor.y
			shape.tex_max.x -= right * source_factor.x
			shape.tex_max.y -= bottom * source_factor.y
		}
		// Clip shape quad
		shape.quad_min.x += left
		shape.quad_min.y += top
		shape.quad_max.x -= right
		shape.quad_max.y -= bottom
	}
	// Discard fully clipped shapes
	// IMPORTANT: This is necessary to avoid crashing!
	if shape.quad_min.x >= shape.quad_max.x || shape.quad_min.y >= shape.quad_max.y do return 0
	// Try use the current matrix
	if core.current_matrix != nil && core.current_matrix^ != core.last_matrix {
		core.matrix_index = u32(len(core.renderer.xforms.data))
		append(&core.renderer.xforms.data, core.current_matrix^)
		core.last_matrix = core.current_matrix^
	}
	// Assign the shape's transform
	shape.xform = core.matrix_index
	// Append the shape
	index := u32(len(core.renderer.shapes.data))
	append(&core.renderer.shapes.data, shape)

	return index
}

// Should be obvious
get_shape_bounding_box :: proc(shape: Shape) -> Box {
	box: Box = {math.F32_MAX, 0}
	switch shape.kind {
	case .None:
	case .Glyph, .Signed_Bezier:
		box.lo = shape.quad_min
		box.hi = shape.quad_max
	case .Line_Segment:
		box.lo = linalg.min(shape.cv0, shape.cv1) - shape.width - 1
		box.hi = linalg.max(shape.cv0, shape.cv1) + shape.width + 1
	case .Box:
		box.lo = shape.cv0 - 1
		box.hi = shape.cv1 + 1
	case .Circle:
		box.lo = shape.cv0 - shape.radius[0] - 1
		box.hi = shape.cv0 + shape.radius[0] + 1
	case .Path:
		for i in 0 ..< shape.count * 3 {
			j := shape.start + i
			box.lo = linalg.min(box.lo, core.renderer.cvs.data[j] - 2)
			box.hi = linalg.max(box.hi, core.renderer.cvs.data[j] + 2)
		}
	case .Polygon:
		for i in 0 ..< shape.count {
			j := shape.start + i
			box.lo = linalg.min(box.lo, core.renderer.cvs.data[j])
			box.hi = linalg.max(box.hi, core.renderer.cvs.data[j])
		}
		box.lo -= 1
		box.hi += 1
	case .Bezier:
		box.lo = linalg.min(shape.cv0, shape.cv1, shape.cv2) - shape.width * 2
		box.hi = linalg.max(shape.cv0, shape.cv1, shape.cv2) + shape.width * 2
	case .Blurred_Box:
		box.lo = shape.cv0 - shape.cv2.x * 3
		box.hi = shape.cv1 + shape.cv2.x * 3
	case .Arc:
		box.lo = shape.cv0 - shape.radius[0] - shape.radius[1]
		box.hi = shape.cv0 + shape.radius[0] + shape.radius[1]
	case .Pie:
		box.lo = shape.cv0 - shape.radius[0]
		box.hi = shape.cv0 + shape.radius[0]
	}

	if shape.kind != .Glyph && shape.kind != .Signed_Bezier {
		switch shape.outline {
		case .None:
		case .Inner_Stroke:
		case .Outer_Stroke, .Glow:
			box.lo -= shape.width
			box.hi += shape.width
		case .Stroke:
			box.lo -= shape.width / 2
			box.hi += shape.width / 2
		}
	}

	return box
}

apply_scissor_box :: proc(target, source: ^Box, clip: Box) {
	left := clip.lo.x - target.lo.x
	source_factor := (source.hi - source.lo) / (target.hi - target.lo)
	if left > 0 {
		target.lo.x += left
		source.lo.x += left * source_factor.x
	}
	top := clip.lo.y - target.lo.y
	if top > 0 {
		target.lo.y += top
		source.lo.y += top * source_factor.y
	}
	right := target.hi.x - clip.hi.x
	if right > 0 {
		target.hi.x -= right
		source.hi.x -= right * source_factor.x
	}
	bottom := target.hi.y - clip.hi.y
	if bottom > 0 {
		target.hi.y -= bottom
		source.hi.y -= bottom * source_factor.y
	}
}

// Get a usable paint index from a `Paint_Option`
paint_index_from_option :: proc(option: Paint_Option) -> Paint_Index {
	switch v in option {
	case Paint_Index:
		return v
	case Paint:
		return add_paint(v)
	case Color:
		return add_paint(Paint{kind = .Solid_Color, col0 = normalize_color(v) * {1.0, 1.0, 1.0, core.opacity}})
	}
	return core.paint
}

set_opacity :: proc(opacity: f32) {
	core.opacity = opacity
}

// add_shape_uv :: proc(shape_index: u32, source: Box, color: Color) {
// 	shape := core.renderer.shapes.data[shape_index]
// 	box := get_shape_bounding_box(shape)
// 	source := source
// 	// Apply scissor clipping
// 	// Shadows are not clipped like other shapes since they are currently only drawn below new layers
// 	// This is subject to change.
// 	if scissor, ok := current_scissor().?; ok {
// 		apply_scissor_box(&box, &source, scissor.box)
// 	}
// 	// Discard fully clipped shapes
// 	if box.lo.x >= box.hi.x || box.lo.y >= box.hi.y do return
// 	// Get texture size
// 	size := [2]f32{f32(core.atlas.width), f32(core.atlas.height)}
// 	// Add vertices
// 	a := add_vertex(
// 		Vertex {
// 			pos = box.lo,
// 			col = color,
// 			uv = source.lo / size,
// 			shape = shape_index,
// 			paint = core.paint,
// 		},
// 	)
// 	b := add_vertex(
// 		Vertex {
// 			pos = [2]f32{box.lo.x, box.hi.y},
// 			col = color,
// 			uv = [2]f32{source.lo.x, source.hi.y} / size,
// 			shape = shape_index,
// 			paint = core.paint,
// 		},
// 	)
// 	c := add_vertex(
// 		Vertex {
// 			pos = box.hi,
// 			col = color,
// 			uv = source.hi / size,
// 			shape = shape_index,
// 			paint = core.paint,
// 		},
// 	)
// 	d := add_vertex(
// 		Vertex {
// 			pos = [2]f32{box.hi.x, box.lo.y},
// 			col = color,
// 			uv = [2]f32{source.hi.x, source.lo.y} / size,
// 			shape = shape_index,
// 			paint = core.paint,
// 		},
// 	)
// 	add_indices(a, b, c, a, c, d)
// }

Line_Join_Style :: enum {
	Round,
	Miter,
}

// Draw one or more line segments connected with miter joints
add_lines :: proc(
	points: [][2]f32,
	width: f32,
	closed: bool = false,
	join_style: Line_Join_Style = .Round,
	paint: Paint_Option = nil,
) {
	if len(points) < 2 {
		return
	}
	switch join_style {
	case .Round:
		for i in 0..<len(points) - 1 {
			add_line(points[i], points[i + 1], width, paint)
		}
	case .Miter:
		v0, v1: [2]f32
		for i in 0 ..< len(points) {
			a := i - 1
			b := i
			c := i + 1
			d := i + 2
			if a < 0 {
				if closed {
					a = len(points) - 1
				} else {
					a = 0
				}
			}
			if closed {
				c = c % len(points)
				d = d % len(points)
			} else {
				c = min(len(points) - 1, c)
				d = min(len(points) - 1, d)
			}
			p0 := points[a]
			p1 := points[b]
			p2 := points[c]
			p3 := points[d]
			if p1 == p2 {
				continue
			}
			if width <= 1.0 {
				add_line(p1, p2, width, paint)
			} else {
				width := width / 2
				line := linalg.normalize(p2 - p1)
				normal := linalg.normalize([2]f32{-line.y, line.x})
				tangent2 := line if p2 == p3 else linalg.normalize(linalg.normalize(p3 - p2) + line)
				miter2: [2]f32 = {-tangent2.y, tangent2.x}
				dot2 := linalg.dot(normal, miter2)
				// Start of segment
				if i == 0 {
					tangent1 := line if p0 == p1 else linalg.normalize(linalg.normalize(p1 - p0) + line)
					miter1: [2]f32 = {-tangent1.y, tangent1.x}
					dot1 := linalg.dot(normal, miter1)
					v0 = p1 - (width / dot1) * miter1
					v1 = p1 + (width / dot1) * miter1
				}
				// End of segment
				nv0 := p2 - (width / dot2) * miter2
				nv1 := p2 + (width / dot2) * miter2
				// Add a polygon for each quad
				add_polygon({v0, v1, nv1, nv0}, paint = paint)
				v0, v1 = nv0, nv1
			}
		}
	}
}

// Why is this here?
// __join_miter :: proc(p0, p1, p2: [2]f32) -> (dot: f32, miter: [2]f32) {
// 	line := linalg.normalize(p2 - p1)
// 	normal := linalg.normalize([2]f32{-line.y, line.x})
// 	tangent := line if p0 == p1 else linalg.normalize(linalg.normalize(p1 - p0) + line)
// 	miter = {-tangent.y, tangent.x}
// 	dot = linalg.dot(normal, miter)
// 	return
// }

// 0-255 -> 0.0-1.0
normalize_color :: proc(color: Color) -> [4]f32 {
	return {f32(color.r) / 255.0, f32(color.g) / 255.0, f32(color.b) / 255.0, f32(color.a) / 255.0}
}

add_line :: proc(a, b: [2]f32, width: f32, paint: Paint_Option = nil) {
	add_shape(
		Shape {
			kind = .Line_Segment,
			cv0 = a,
			cv1 = b,
			width = width - 1,
			paint = paint_index_from_option(paint),
		},
	)
}

add_quadratic_bezier :: proc(a, b, c: [2]f32, width: f32, paint: Paint_Option) {
	shape := Shape {
		kind  = .Bezier,
		cv0   = a,
		cv1   = b,
		cv2   = c,
		width = width,
		paint = paint_index_from_option(paint),
	}
	add_shape(shape)
}

add_cubic_bezier :: proc(a, b, c, d: [2]f32, width: f32, paint: Paint_Option) {
	ab := linalg.lerp(a, b, 0.5)
	cd := linalg.lerp(c, d, 0.5)
	mp := linalg.lerp(ab, cd, 0.5)
	add_linked_shapes(
		Shape{kind = .Bezier, cv0 = a, cv1 = ab, cv2 = mp, width = width},
		Shape{kind = .Bezier, cv0 = mp, cv1 = cd, cv2 = d, width = width},
		mode = .Union,
		paint = paint,
	)
}

add_polygon :: proc(vertices: [][2]f32, paint: Paint_Option = nil) {
	add_shape(Shape {
		kind  = .Polygon,
		start = add_vertices(..vertices),
		count = u32(len(vertices)),
		paint = paint_index_from_option(paint),
	})
}

add_polygon_lines :: proc(vertices: [][2]f32, width: f32 = 1, paint: Paint_Option = nil) {
	add_lines(vertices, width, true, paint = paint)
}

lerp_cubic_bezier :: proc(a, b, c, d: [2]f32, t: f32) -> [2]f32 {
	weights: matrix[4, 4]f32 = {1, 0, 0, 0, -3, 3, 0, 0, 3, -6, 3, 0, -1, 3, -3, 1}
	times: matrix[1, 4]f32 = {1, t, t * t, t * t * t}
	return [2]f32 {
		(times * weights * (matrix[4, 1]f32){a.x, b.x, c.x, d.x})[0][0],
		(times * weights * (matrix[4, 1]f32){a.y, b.y, c.y, d.y})[0][0],
	}
}

add_pie :: proc(center: [2]f32, from, to, radius: f32, paint: Paint_Option) {
	shape := make_pie(center, from, to, radius)
	shape.paint = paint_index_from_option(paint)
	add_shape(shape)
}

add_pie_lines :: proc(center: [2]f32, from, to, radius: f32, width: f32, paint: Paint_Option) {
	shape := make_pie(center, from, to, radius)
	shape.outline = .Inner_Stroke
	shape.width = width
	shape.paint = paint_index_from_option(paint)
	add_shape(shape)
}

add_arc :: proc(center: [2]f32, from, to: f32, inner, outer: f32, square: bool = false, paint: Paint_Option = nil) {
	shape := make_arc(center, from, to, inner, outer, square)
	shape.paint = paint_index_from_option(paint)
	add_shape(shape)
}

add_circle :: proc(center: [2]f32, radius: f32, paint: Paint_Option = nil) {
	add_shape(
		Shape {
			kind = .Circle,
			cv0 = center,
			radius = radius,
			paint = paint_index_from_option(paint),
		},
	)
}

add_circle_lines :: proc(center: [2]f32, radius, width: f32, paint: Paint_Option = nil) {
	add_shape(
		Shape {
			kind = .Circle,
			cv0 = center,
			radius = radius,
			width = width,
			outline = .Inner_Stroke,
			paint = paint_index_from_option(paint),
		},
	)
}

add_box :: proc(box: Box, radius: [4]f32 = {}, paint: Paint_Option = nil) {
	shape := make_box(box, radius)
	shape.paint = paint_index_from_option(paint)
	add_shape(shape)
}

add_box_lines :: proc(box: Box, width: f32, radius: [4]f32 = {}, paint: Paint_Option = nil, outline: Shape_Outline = .Inner_Stroke) {
	shape := make_box(box, radius)
	shape.outline = outline
	shape.width = width
	shape.paint = paint_index_from_option(paint)
	add_shape(shape)
}

add_box_shadow :: proc(box: Box, corner_radius, blur_radius: f32, color: Color) {
	add_shape(
		Shape {
			kind = .Blurred_Box,
			radius = corner_radius,
			cv0 = box.lo,
			cv1 = box.hi,
			cv2 = {0 = blur_radius},
			paint = paint_index_from_option(color),
		},
	)
}

add_spinner :: proc(center: [2]f32, radius: f32, color: Color) {
	from := f32(run_time() * 2) * math.PI
	to := from + 2.5 + math.sin(f32(run_time() * 3)) * 1

	width := radius * 0.25

	add_arc(center, from, to, radius - width, radius, paint = color)
}

add_arrow :: proc(pos: [2]f32, scale: f32, thickness: f32, angle: f32 = 0, paint: Paint_Option = nil) {
	push_matrix()
	defer pop_matrix()
	translate(pos)
	rotate(angle)
	translate(-pos)
	add_lines(
		{
			pos + [2]f32{-0.5, -0.877} * scale,
			pos + [2]f32{0.5, 0} * scale,
			pos + [2]f32{-0.5, 0.877} * scale,
		},
		thickness,
		paint = paint,
	)
}

add_check :: proc(pos: [2]f32, scale: f32, thickness: f32, color: Color) {
	add_lines(
		{pos + {-1, -0.047} * scale, pos + {-0.333, 0.619} * scale, pos + {1, -0.713} * scale},
		thickness,
		paint = color,
	)
}

add_vertices :: proc(vertices: ..[2]f32) -> u32 {
	index := u32(len(core.renderer.cvs.data))
	append(&core.renderer.cvs.data, ..vertices)
	return index
}
