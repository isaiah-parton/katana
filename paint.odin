package katana
// Time to work out the intended usage of this renderer
//
// Index of a paint that was already added
// this exists so paints can be reused
// 		Paint_Handle :: distinct int
//
// We could add an optional paint argument to all draw procedures
// 		fill_box(..., Solid_Color(BROWN))
//
// If none is provided, the paint in `core.draw_state` will be used
// 		set_paint(linear_gradient({100, 200}, {520, 340}, RED, MAROON))
// 		stroke_box(...)
// 		fill_circle(...)
//
// Or pass a `Paint_Handle`
// 		paint0 := add_paint(GRAY(0.5))
// 		paint1 := add_paint(GRAY(0.8))
// 		fill_box(..., paint0)
// 		fill_box(..., paint1)
// 		stroke_box(..., paint0)
// 		stroke_box(..., paint1)
//
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:mem"
import "core:reflect"
import "core:testing"

import "vendor:wgpu"

MAX_PATH_POINTS :: 400
MAX_MATRICES :: 100
MAX_DRAW_CALLS :: 64

MAX_FONTS :: 100

MAX_ATLASES :: 8
MIN_ATLAS_SIZE :: 1024
MAX_ATLAS_SIZE :: 8192

BUFFER_SIZE :: mem.Megabyte

Matrix :: matrix[4, 4]f32

Paint_Kind :: enum u32 {
	None,
	Solid_Color,
	Atlas_Sample,
	User_Texture_Sample,
	Skeleton,
	Linear_Gradient,
	Radial_Gradient,
	Distance_Field,
	Wheel_Gradient,
	Triangle_Gradient,
}

Stroke_Justify :: enum {
	// TODO: define inner and outer
	Inner,
	Center,
	Outer,
}

// The paint data sent to the GPU
Paint :: struct #align (8) {
	kind:  Paint_Kind,
	noise: f32,
	cv0:   [2]f32,
	cv1:   [2]f32,
	cv2:   [2]f32,
	cv3:   [2]f32,
	pad0:  [2]u32,
	col0:  [4]f32,
	col1:  [4]f32,
	col2:  [4]f32,
}

Paint_Index :: distinct u32

Paint_Option :: union {
	Paint_Index,
	Paint,
	Color,
}

Index :: u16

// A call to the GPU to draw some stuff
Draw_Call :: struct {
	user_texture:      Maybe(wgpu.Texture),
	user_sampler_desc: Maybe(wgpu.SamplerDescriptor),
	first_shape:       int,
	shape_count:       int,
	index:             int,
}

Scissor :: struct {
	box:   Box,
	shape: u32,
}

@(test)
test_gpu_structs :: proc(t: ^testing.T) {
	assert(reflect.struct_field_by_name(Paint, "kind").offset == 0)
	assert(reflect.struct_field_by_name(Paint, "cv0").offset == 8)
	assert(reflect.struct_field_by_name(Paint, "cv1").offset == 16)
	assert(reflect.struct_field_by_name(Paint, "col0").offset == 32)
	assert(reflect.struct_field_by_name(Paint, "col1").offset == 48)

	assert(reflect.struct_field_by_name(Paint, "kind").offset == 0)
	assert(reflect.struct_field_by_name(Paint, "next").offset == 4)
	assert(reflect.struct_field_by_name(Paint, "quad_min").offset == 4)
	assert(reflect.struct_field_by_name(Paint, "quad_max").offset == 4)
	assert(reflect.struct_field_by_name(Paint, "tex_min").offset == 4)
	assert(reflect.struct_field_by_name(Paint, "tex_max").offset == 4)
	assert(reflect.struct_field_by_name(Paint, "cv0").offset == 8)
	assert(reflect.struct_field_by_name(Paint, "cv1").offset == 16)
	assert(reflect.struct_field_by_name(Paint, "cv2").offset == 24)
	assert(reflect.struct_field_by_name(Paint, "corners").offset == 32)
	assert(reflect.struct_field_by_name(Paint, "radius").offset == 48)
	assert(reflect.struct_field_by_name(Paint, "width").offset == 52)
	assert(reflect.struct_field_by_name(Paint, "start").offset == 56)
	assert(reflect.struct_field_by_name(Paint, "count").offset == 60)
	assert(reflect.struct_field_by_name(Paint, "stroke").offset == 64)
	assert(reflect.struct_field_by_name(Paint, "xform").offset == 68)
	assert(reflect.struct_field_by_name(Paint, "mode").offset == 72)
}

push_scissor :: proc(shape: Shape) {
	shape := shape
	shape.mode = .Intersection
	if scissor, ok := current_scissor().?; ok {
		shape.next = scissor.shape
	}
	push_stack(
		&core.scissor_stack,
		Scissor{box = get_shape_bounding_box(shape), shape = u32(len(core.renderer.shapes.data))},
	)
	append(&core.renderer.shapes.data, shape)
}

pop_scissor :: proc() {
	pop_stack(&core.scissor_stack)
}

current_scissor :: proc() -> Maybe(Scissor) {
	if !core.disable_scissor && core.scissor_stack.height > 0 {
		return core.scissor_stack.items[core.scissor_stack.height - 1]
	}
	return nil
}

@(deferred_none = enable_scissor)
disable_scissor :: proc() -> bool {
	core.disable_scissor = true
	return core.disable_scissor
}

enable_scissor :: proc() {
	core.disable_scissor = false
}

save_scissor :: proc() {
	push_stack(&core.scissor_stack_stack, core.scissor_stack)
	core.scissor_stack.height = 0
}

restore_scissor :: proc() {
	core.scissor_stack = pop_stack(&core.scissor_stack_stack)
}

make_linear_gradient :: proc(
	start_point, end_point: [2]f32,
	start_color, end_color: Color,
) -> Paint {
	diff := linalg.abs(normalize_color(end_color) - normalize_color(start_color))
	return Paint {
		kind = .Linear_Gradient,
		noise = (linalg.length(end_point - start_point) / 255.0) * 0.0025,
		cv0 = start_point,
		cv1 = end_point,
		col0 = normalize_color(start_color),
		col1 = normalize_color(end_color),
	}
}

make_radial_gradient :: proc(center: [2]f32, radius: f32, inner, outer: Color) -> Paint {
	diff := linalg.abs(normalize_color(outer) - normalize_color(inner))
	return Paint {
		kind = .Radial_Gradient,
		noise = max(0.0, (1.0 - (diff.r + diff.g + diff.b + diff.a) * 0.25) * 0.05),
		cv0 = center,
		cv1 = {radius, 0},
		col0 = normalize_color(inner),
		col1 = normalize_color(outer),
	}
}

make_wheel_gradient :: proc(center: [2]f32) -> Paint {
	return Paint{kind = .Wheel_Gradient, cv0 = center}
}

make_tri_gradient :: proc(points: [3][2]f32, colors: [3]Color) -> Paint {
	return Paint {
		kind = .Triangle_Gradient,
		cv0 = points[0],
		cv1 = points[1],
		cv2 = points[2],
		col0 = normalize_color(colors[0]),
		col1 = normalize_color(colors[1]),
		col2 = normalize_color(colors[2]),
	}
}

make_atlas_sample :: proc(source, target: Box, tint: Color) -> Paint {
	source := Box{source.lo / core.atlas_size, source.hi / core.atlas_size}
	return Paint {
		kind = .Atlas_Sample,
		cv0 = source.lo,
		cv1 = source.hi - source.lo,
		cv2 = target.lo,
		cv3 = target.hi - target.lo,
		col0 = normalize_color(tint),
	}
}

add_paint :: proc(paint: Paint) -> Paint_Index {
	index := Paint_Index(len(core.renderer.paints.data))
	append(&core.renderer.paints.data, paint)
	return index
}

set_paint :: proc(paint: Paint_Option) {
	core.paint = paint_index_from_option(paint)
}

set_shape :: proc(shape: u32) {
	core.shape = shape
}

@(private)
add_xform :: proc(xform: Matrix) -> u32 {
	index := u32(len(core.renderer.xforms.data))
	append(&core.renderer.xforms.data, xform)
	return index
}

current_matrix :: proc() -> Maybe(Matrix) {
	if core.matrix_stack.height > 0 {
		return core.matrix_stack.items[core.matrix_stack.height - 1]
	}
	return nil
}

push_matrix :: proc() {
	push_stack(&core.matrix_stack, current_matrix().? or_else identity_matrix())
	core.current_matrix = &core.matrix_stack.items[core.matrix_stack.height - 1]
}

pop_matrix :: proc() {
	pop_stack(&core.matrix_stack)
	core.current_matrix = &core.matrix_stack.items[max(0, core.matrix_stack.height - 1)]
}

identity_matrix :: proc() -> Matrix {
	return {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1}
}

translate :: proc(vector: [2]f32) {
	core.current_matrix^ *= linalg.matrix4_translate([3]f32{vector.x, vector.y, 0})
}

rotate :: proc(angle: f32) {
	cosres := math.cos(angle)
	sinres := math.sin(angle)
	rotation_matrix: Matrix = {cosres, -sinres, 0, 0, sinres, cosres, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1}
	core.current_matrix^ *= rotation_matrix
}

scale :: proc(factor: [2]f32) {
	core.current_matrix^ *= linalg.matrix4_scale([3]f32{factor.x, factor.y, 1})
}

set_sampler_descriptor :: proc(desc: wgpu.SamplerDescriptor) {
	if core.current_draw_call == nil do return
	if core.current_draw_call.user_sampler_desc != nil {
		append_draw_call()
	}
	core.current_draw_call.user_sampler_desc = desc
}

set_texture :: proc(texture: wgpu.Texture) {
	core.user_texture = texture
	if core.current_draw_call == nil do return
	if core.current_draw_call.user_texture == core.user_texture do return
	if core.current_draw_call.user_texture != nil {
		append_draw_call()
	}
	core.current_draw_call.user_texture = core.user_texture
}

@(private)
append_draw_call :: proc() {
	if core.current_draw_call != nil {
		core.current_draw_call.shape_count =
			len(core.renderer.shapes.data) - core.current_draw_call.first_shape
	}
	append(
		&core.draw_calls,
		Draw_Call {
			index = core.draw_call_index,
			first_shape = len(core.renderer.shapes.data),
			user_texture = core.user_texture,
		},
	)
	core.current_draw_call = &core.draw_calls[len(core.draw_calls) - 1]
}

set_draw_order :: proc(index: int) {
	if core.current_draw_call != nil &&
	   core.current_draw_call.first_shape == len(core.renderer.shapes.data) {
		core.current_draw_call.index = index
		return
	}
	if core.draw_call_index != index {
		core.draw_call_index = index
		append_draw_call()
	}
}

get_draw_order :: proc() -> int {
	return core.draw_call_index
}

