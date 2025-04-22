package katana

import "core:math"
import "core:math/linalg"

// Path operations
begin_path :: proc() {
	core.path_start = u32(len(core.renderer.cvs.data))
}

move_to :: proc(p: [2]f32) {
	core.path_point = p
}

quad_bezier_to :: proc(cp, p: [2]f32) {
	append(&core.renderer.cvs.data, core.path_point, cp, p)
	move_to(p)
}

line_to :: proc(p: [2]f32) {
	quad_bezier_to(linalg.lerp(core.path_point, p, 0.5), p)
}

close_path :: proc() {
	line_to(core.renderer.cvs.data[core.path_start])
}

fill_path :: proc(paint: Paint_Option) -> u32 {
	vertex_count := u32(len(core.renderer.cvs.data)) - core.path_start
	return add_shape(
		Shape{kind = .Path, start = core.path_start, count = vertex_count / 3, paint = paint_index_from_option(paint)},
	)
}
