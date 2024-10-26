package vgo

import "core:fmt"
import "core:time"
import "vendor:wgpu"

@(private)
core: Core

@(private)
Core :: struct {
	renderer:             Renderer,
	// Timing
	start_time:           time.Time,
	frame_time:           time.Time,
	fps:									f32,
	// Text layout
	text_glyphs:          [dynamic]Text_Glyph,
	text_lines:           [dynamic]Text_Line,
	// Transform matrices
	matrix_stack:         Stack(Matrix, 128),
	current_matrix:       ^Matrix,
	last_matrix:          Matrix,
	matrix_index:         u32,
	fonts:                [128]Maybe(Font),
	fallback_font:        Font,
	// Scissors are capped at 8 for the sake of sanity
	scissor_stack:        Stack(Scissor, 8),
	// Draw calls for ordered drawing
	draw_calls:           [dynamic]Draw_Call,
	draw_call_index:      int,
	current_draw_call:    ^Draw_Call,
	// User defined texture
	user_texture:         wgpu.Texture,
	// Atlas for fonts and icons
	atlas_texture:        wgpu.Texture,
	atlas_size:           f32,
	atlas_offset:         [2]f32,
	atlas_content_height: f32,
	// Current draw state
	paint:                u32,
	shape:                u32,
	xform:                u32,
	path_start:           u32,
	path_point:           [2]f32,
}

// Call before using vgo
start :: proc(device: wgpu.Device, surface: wgpu.Surface, surface_format: wgpu.TextureFormat) {
	init_renderer_with_device_and_surface(&core.renderer, device, surface, surface_format)

	core.atlas_size = f32(min(core.renderer.device_limits.maxTextureDimension2D, 8196))
	core.atlas_texture = wgpu.DeviceCreateTexture(
		core.renderer.device,
		&{
			usage = {.CopySrc, .CopyDst, .TextureBinding},
			dimension = ._2D,
			size = {u32(core.atlas_size), u32(core.atlas_size), 1},
			format = .RGBA8Unorm,
			mipLevelCount = 1,
			sampleCount = 1,
		},
	)
	core.start_time = time.now()
}

// Call when you're done using vgo
done :: proc() {
	delete(core.draw_calls)
}

get_fps :: proc() -> f32 {
	return core.fps
}

new_frame :: proc() {
	core.fps = f32(1.0 / time.duration_seconds(time.since(core.frame_time)))
	core.frame_time = time.now()

	clear(&core.renderer.vertices)
	clear(&core.renderer.indices)
	clear(&core.renderer.shapes.data)
	clear(&core.renderer.paints.data)
	clear(&core.renderer.cvs.data)
	clear(&core.renderer.xforms.data)

	clear(&core.draw_calls)
	core.current_draw_call = nil

	add_paint(Paint{kind = .None})

	append_draw_call()

	core.matrix_stack.height = 0
	push_matrix()
}

get_seconds :: proc() -> f32 {
	return f32(time.duration_seconds(time.since(core.start_time)))
}

get_atlas_box :: proc(size: [2]f32) -> Box {
	if core.atlas_offset.x + size.x > core.atlas_size {
		core.atlas_offset = {0, core.atlas_content_height}
		core.atlas_content_height = 0
		if core.atlas_offset.y + size.y > core.atlas_size {
			core.atlas_offset = {}
		}
	}
	box := Box{core.atlas_offset, core.atlas_offset + size}
	core.atlas_offset.x += size.x
	core.atlas_content_height = max(core.atlas_content_height, size.y)
	return box
}

blit_texture_to_atlas :: proc(texture: wgpu.Texture) -> Box {
	texture_size := [2]f32{f32(wgpu.TextureGetWidth(texture)), f32(wgpu.TextureGetHeight(texture))}
	box := get_atlas_box(texture_size)
	enc := wgpu.DeviceCreateCommandEncoder(core.renderer.device)
	wgpu.CommandEncoderCopyTextureToTexture(
		enc,
		&{texture = texture},
		&{texture = core.atlas_texture, origin = {x = u32(box.lo.x), y = u32(box.lo.y)}},
		&{
			width = u32(box.hi.x - box.lo.x),
			height = u32(box.hi.y - box.lo.y),
			depthOrArrayLayers = 1,
		},
	)
	wgpu.QueueSubmit(core.renderer.queue, {wgpu.CommandEncoderFinish(enc)})
	wgpu.CommandEncoderRelease(enc)
	return box
}

Stack :: struct($T: typeid, $N: int) {
	items:  [N]T,
	height: int,
}

push_stack :: proc(stack: ^Stack($T, $N), item: T) -> bool {
	if stack.height < 0 || stack.height >= N {
		return false
	}
	stack.items[stack.height] = item
	stack.height += 1
	return true
}

pop_stack :: proc(stack: ^Stack($T, $N)) {
	stack.height -= 1
}

inject_stack :: proc(stack: ^Stack($T, $N), at: int, item: T) -> bool {
	if at == stack.height {
		return push_stack(stack, item)
	}
	copy(stack.items[at + 1:], stack.items[at:])
	stack.items[at] = item
	stack.height += 1
	return true
}

clear_stack :: proc(stack: ^Stack($T, $N)) {
	stack.height = 0
}
