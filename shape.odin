package vgo

import "core:fmt"
import "core:math"
import "core:math/ease"
import "core:math/linalg"
import "core:time"

// These should be self-explanitory
Shape_Kind :: enum u32 {
	Normal,
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
}

Shape_Outline :: enum u32 {
	None,
	Stroke,
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
	kind:    Shape_Kind,
	next:    u32,
	cv0:     [2]f32,
	cv1:     [2]f32,
	cv2:     [2]f32,
	radius:  [4]f32,
	width:   f32,
	start:   u32,
	count:   u32,
	outline: Shape_Outline,
	xform:   u32,
	mode:    Shape_Mode,
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

// Constructors for GPU shapes
// ---

make_box :: proc(box: Box, radius: [4]f32) -> Shape {
	return Shape{kind = .Box, radius = radius, cv0 = box.lo, cv1 = box.hi}
}

make_circle :: proc(center: [2]f32, radius: f32) -> Shape {
	return Shape{kind = .Circle, cv0 = center, radius = radius}
}

make_arc :: proc(center: [2]f32, from, to, inner, outer: f32) -> Shape {
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
draw_linked_shapes :: proc(shapes: ..Shape, mode: Shape_Mode = .Union, paint: Paint_Option = nil) {
	bounds := get_shape_bounding_box(shapes[0])
	shape: Shape
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
	draw_shape_with_bounds(add_shape(shape), bounds, paint)
}

// Applies the current transform matrix and scissor, then queues the shape to
// be sent to the GPU.
add_shape :: proc(shape: Shape) -> u32 {
	index := u32(len(core.renderer.shapes.data))
	shape := shape
	// Apply the last scissor shape
	if scissor, ok := current_scissor().?; ok && scissor.shape != 0 {
		shape.next = scissor.shape
	}
	// Try use the current matrix
	if core.current_matrix != nil && core.current_matrix^ != core.last_matrix {
		core.matrix_index = u32(len(core.renderer.xforms.data))
		append(&core.renderer.xforms.data, core.current_matrix^)
		core.last_matrix = core.current_matrix^
	}
	shape.xform = core.matrix_index
	// Append the shape
	append(&core.renderer.shapes.data, shape)
	return index
}

// Should be obvious
get_shape_bounding_box :: proc(shape: Shape) -> Box {
	box: Box = {math.F32_MAX, 0}
	switch shape.kind {
	case .Normal:
	case .Line_Segment:
		box.lo = shape.cv0 - shape.width
		box.hi = shape.cv1 + shape.width
	case .Glyph:
		box.lo = shape.cv0
		box.hi = shape.cv1
	case .Box:
		box.lo = shape.cv0
		box.hi = shape.cv1
	case .Circle:
		box.lo = shape.cv0 - shape.radius[0]
		box.hi = shape.cv0 + shape.radius[0]
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
		box.lo = shape.cv0 - shape.cv1 * 3
		box.hi = shape.cv0 + shape.cv1 * 3
	case .Arc:
		box.lo = shape.cv0 - shape.radius[0] - shape.radius[1]
		box.hi = shape.cv0 + shape.radius[0] + shape.radius[1]
	case .Pie:
		box.lo = shape.cv0 - shape.radius[0]
		box.hi = shape.cv0 + shape.radius[0]
	}

	if shape.outline == .Stroke {
		box.lo -= shape.width / 2
		box.hi += shape.width / 2
	} else if shape.outline == .Glow {
		box.lo -= shape.width
		box.hi += shape.width
	}

	box.lo -= 1
	box.hi += 1

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
paint_index_from_option :: proc(option: Paint_Option) -> u32 {
	switch v in option {
	case u32:
		return v
	case Paint:
		return add_paint(v)
	case Color:
		return 0
	}
	return core.paint
}

draw_shape_with_bounds :: proc(shape_index: u32, bounds: Box, paint: Paint_Option = nil) {
	bounds := bounds
	// Apply scissor clipping
	if scissor, ok := current_scissor().?; ok {
		bounds.lo = linalg.max(bounds.lo, scissor.box.lo)
		bounds.hi = linalg.min(bounds.hi, scissor.box.hi)
	}
	// Discard fully clipped shapes
	if bounds.lo.x >= bounds.hi.x || bounds.lo.y >= bounds.hi.y do return
	// Determine vertex color
	vertex_color := paint.(Color) or_else 255
	paint_index := paint_index_from_option(paint)
	// Add vertices
	a := add_vertex(
		Vertex {
			pos = bounds.lo,
			col = vertex_color,
			uv = 0,
			shape = shape_index,
			paint = paint_index,
		},
	)
	b := add_vertex(
		Vertex {
			pos = {bounds.lo.x, bounds.hi.y},
			col = vertex_color,
			uv = {0, 1},
			shape = shape_index,
			paint = paint_index,
		},
	)
	c := add_vertex(
		Vertex {
			pos = bounds.hi,
			col = vertex_color,
			uv = 1,
			shape = shape_index,
			paint = paint_index,
		},
	)
	d := add_vertex(
		Vertex {
			pos = {bounds.hi.x, bounds.lo.y},
			col = vertex_color,
			uv = {1, 0},
			shape = shape_index,
			paint = paint_index,
		},
	)
	add_indices(a, b, c, a, c, d)
}

// Render an already added shape
draw_shape_by_index :: proc(shape_index: u32, paint: Paint_Option = nil) {
	draw_shape_with_bounds(
		shape_index,
		get_shape_bounding_box(core.renderer.shapes.data[shape_index]),
		paint,
	)
}

draw_shape_struct :: proc(shape: Shape, paint: Paint_Option = nil) {
	draw_shape_by_index(add_shape(shape), paint)
}

draw_shape :: proc {
	draw_shape_struct,
	draw_shape_by_index,
}

// draw_shape_uv :: proc(shape_index: u32, source: Box, color: Color) {
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

// Draw one or more line segments connected with miter joints
draw_joined_lines :: proc(
	points: [][2]f32,
	thickness: f32,
	color: Color,
	closed: bool = false,
	justify: Stroke_Justify = .Center,
) {
	if len(points) < 2 {
		return
	}
	left, right: f32
	switch justify {
	case .Center:
		left = thickness / 2
		right = left
	case .Outer:
		left = thickness
	case .Inner:
		right = thickness
	}
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
			v0 = p1 - (left / dot1) * miter1
			v1 = p1 + (right / dot1) * miter1
		}
		// End of segment
		nv0 := p2 - (left / dot2) * miter2
		nv1 := p2 + (right / dot2) * miter2
		// Add a polygon for each quad
		fill_polygon({v0, v1, nv1, nv0}, color)
		v0, v1 = nv0, nv1
	}
}

__join_miter :: proc(p0, p1, p2: [2]f32) -> (dot: f32, miter: [2]f32) {
	line := linalg.normalize(p2 - p1)
	normal := linalg.normalize([2]f32{-line.y, line.x})
	tangent := line if p0 == p1 else linalg.normalize(linalg.normalize(p1 - p0) + line)
	miter = {-tangent.y, tangent.x}
	dot = linalg.dot(normal, miter)
	return
}

// 0-255 -> 0.0-1.0
normalize_color :: proc(color: Color) -> [4]f32 {
	return {f32(color.r) / 255.0, f32(color.g) / 255.0, f32(color.b) / 255.0, f32(color.a) / 255.0}
}

// Draw something from the font atlas
// draw_glyph :: proc(source, target: Box, tint: Color) {
// 	source, target := source, target
// 	if scissor, ok := current_scissor().?; ok {
// 		left := scissor.box.lo.x - target.lo.x
// 		if left > 0 {
// 			target.lo.x += left
// 			source.lo.x += left
// 		}
// 		top := scissor.box.lo.y - target.lo.y
// 		if top > 0 {
// 			target.lo.y += top
// 			source.lo.y += top
// 		}
// 		right := target.hi.x - scissor.box.hi.x
// 		if right > 0 {
// 			target.hi.x -= right
// 			source.hi.x -= right
// 		}
// 		bottom := target.hi.y - scissor.box.hi.y
// 		if bottom > 0 {
// 			target.hi.y -= bottom
// 			source.hi.y -= bottom
// 		}
// 		if target.lo.x >= target.hi.x || target.lo.y >= target.hi.y do return
// 	}
// 	size: [2]f32 = {f32(core.atlas.width), f32(core.atlas.height)}
// 	shape_index := add_shape(Shape{kind = .Normal})
// 	a := add_vertex(
// 		Vertex{pos = target.lo, col = tint, uv = source.lo / size, shape = shape_index, paint = 1},
// 	)
// 	b := add_vertex(
// 		Vertex {
// 			pos = [2]f32{target.lo.x, target.hi.y},
// 			col = tint,
// 			uv = [2]f32{source.lo.x, source.hi.y} / size,
// 			shape = shape_index,
// 			paint = 1,
// 		},
// 	)
// 	c := add_vertex(
// 		Vertex{pos = target.hi, col = tint, uv = source.hi / size, shape = shape_index, paint = 1},
// 	)
// 	d := add_vertex(
// 		Vertex {
// 			pos = [2]f32{target.hi.x, target.lo.y},
// 			col = tint,
// 			uv = [2]f32{source.hi.x, source.lo.y} / size,
// 			shape = shape_index,
// 			paint = 1,
// 		},
// 	)
// 	add_indices(a, b, c, a, c, d)
// }

draw_line :: proc(a, b: [2]f32, width: f32, paint: Paint_Option) {
	draw_shape(Shape{kind = .Line_Segment, cv0 = a, cv1 = b, width = width}, paint)
}

stroke_quad_bezier :: proc(a, b, c: [2]f32, width: f32, paint: Paint_Option) {
	shape_index := add_shape(Shape{kind = .Bezier, cv0 = a, cv1 = b, cv2 = c, width = width})
	draw_shape(shape_index, paint)
}

stroke_cubic_bezier :: proc(a, b, c, d: [2]f32, width: f32, paint: Paint_Option) {
	ab := linalg.lerp(a, b, 0.5)
	cd := linalg.lerp(c, d, 0.5)
	mp := linalg.lerp(ab, cd, 0.5)
	draw_linked_shapes(
		Shape{kind = .Bezier, cv0 = a, cv1 = ab, cv2 = mp, width = width},
		Shape{kind = .Bezier, cv0 = mp, cv1 = cd, cv2 = d, width = width},
		mode = .Union,
		paint = paint,
	)
}

add_polygon_shape :: proc(pts: ..[2]f32) -> u32 {
	shape := Shape {
		kind  = .Polygon,
		start = u32(len(core.renderer.cvs.data)),
	}
	for p in pts {
		append(&core.renderer.cvs.data, p)
		shape.count += 1
	}
	return add_shape(shape)
}

fill_polygon :: proc(pts: [][2]f32, paint: Paint_Option) {
	shape := Shape {
		kind  = .Polygon,
		start = u32(len(core.renderer.cvs.data)),
		count = u32(len(pts)),
	}
	append(&core.renderer.cvs.data, ..pts)
	draw_shape(shape, paint)
}

lerp_cubic_bezier :: proc(a, b, c, d: [2]f32, t: f32) -> [2]f32 {
	weights: matrix[4, 4]f32 = {1, 0, 0, 0, -3, 3, 0, 0, 3, -6, 3, 0, -1, 3, -3, 1}
	times: matrix[1, 4]f32 = {1, t, t * t, t * t * t}
	return [2]f32 {
		(times * weights * (matrix[4, 1]f32){a.x, b.x, c.x, d.x})[0][0],
		(times * weights * (matrix[4, 1]f32){a.y, b.y, c.y, d.y})[0][0],
	}
}

fill_pie :: proc(center: [2]f32, from, to, radius: f32, paint: Paint_Option) {
	draw_shape(make_pie(center, from, to, radius), paint)
}

stroke_pie :: proc(center: [2]f32, from, to, radius: f32, width: f32, paint: Paint_Option) {
	shape := make_pie(center, from, to, radius)
	shape.outline = .Stroke
	shape.width = width
	draw_shape(shape, paint)
}

draw_arc :: proc(center: [2]f32, from, to: f32, radius, width: f32, paint: Paint_Option = nil) {
	draw_shape(make_arc(center, from, to, radius, width), paint)
}

fill_circle :: proc(center: [2]f32, radius: f32, paint: Paint_Option) {
	draw_shape(Shape{kind = .Circle, cv0 = center, radius = radius}, paint)
}

draw_circle_stroke :: proc(center: [2]f32, radius, width: f32, color: Color) {
	shape_index := add_shape(
		Shape{kind = .Circle, cv0 = center, radius = radius, width = width, outline = .Stroke},
	)
	draw_shape(shape_index, color)
}


fill_box :: proc(box: Box, paint: Paint_Option, radius: [4]f32 = {}) {
	draw_shape(make_box(box, radius), paint)
}

stroke_box :: proc(box: Box, width: f32, paint: Paint_Option, radius: [4]f32 = {}) {
	shape := make_box(box, radius)
	shape.outline = .Stroke
	shape.width = width
	draw_shape(shape, paint)
}

// TODO: document corner order
draw_rounded_box_corners_fill :: proc(box: Box, corners: [4]f32, color: Color) {
	if box.hi.x <= box.lo.x || box.hi.y <= box.lo.y {
		return
	}
	draw_shape(make_box(box, corners), color)
}

draw_rounded_box_fill :: proc(box: Box, radius: f32, color: Color) {
	if box.hi.x <= box.lo.x || box.hi.y <= box.lo.y {
		return
	}
	draw_shape(make_box(box, radius), color)
}

draw_rounded_box_shadow :: proc(box: Box, corner_radius, blur_radius: f32, color: Color) {
	if box.hi.x <= box.lo.x || box.hi.y <= box.lo.y {
		return
	}
	draw_shape(
		add_shape(
			Shape {
				kind = .Blurred_Box,
				radius = corner_radius,
				cv0 = box.lo,
				cv1 = box.hi,
				cv2 = {0 = blur_radius},
			},
		),
		color,
	)
}

draw_rounded_box_stroke :: proc(box: Box, radius, width: f32, color: Color) {
	if box.hi.x <= box.lo.x || box.hi.y <= box.lo.y {
		return
	}
	radius := min(radius, (box.hi.x - box.lo.x) / 2, (box.hi.y - box.lo.y) / 2)
	draw_shape(
		add_shape(
			Shape {
				kind = .Box,
				radius = radius,
				cv0 = box.lo,
				cv1 = box.hi,
				width = width,
				outline = .Stroke,
			},
		),
		color,
	)
}

draw_spinner :: proc(center: [2]f32, radius: f32, color: Color) {
	from := f32(time.duration_seconds(time.since(core.start_time)) * 2) * math.PI
	to := from + 2.5 + math.sin(f32(time.duration_seconds(time.since(core.start_time)) * 3)) * 1

	width := radius * 0.25

	draw_arc(center, from, to, radius - width, radius, color)
}

draw_arrow :: proc(pos: [2]f32, scale: f32, color: Color) {
	draw_joined_lines(
		{pos + {-1, -0.5} * scale, pos + {0, 0.5} * scale, pos + {1, -0.5} * scale},
		2,
		color,
	)
}

draw_check :: proc(pos: [2]f32, scale: f32, color: Color) {
	draw_joined_lines(
		{pos + {-1, -0.047} * scale, pos + {-0.333, 0.619} * scale, pos + {1, -0.713} * scale},
		2,
		color,
	)
}
