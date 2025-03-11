package katana

import "base:runtime"
import "core:fmt"
import "core:time"
import "vendor:wgpu"
import "vendor:wgpu/sdl2glue"
import "vendor:sdl2"

@(private)
core: Core

@(private)
Core :: struct {
	renderer:             Renderer,
	start_time:           time.Time,
	frame_time:           time.Time,
	frames_this_second:   int,
	last_second:          time.Time,
	delta_time:           f32,
	fps:                  f32,
	matrix_stack:         Stack(Matrix, 128),
	current_matrix:       ^Matrix,
	last_matrix:          Matrix,
	matrix_index:         u32,
	default_font:         Font,
	current_font:         Font,
	fallback_font:        Maybe(Font),
	scissor_stack:        Stack(Scissor, 8),
	scissor_stack_stack:  Stack(Stack(Scissor, 8), 8),
	disable_scissor:      bool,
	opacity:              f32,
	draw_calls:           [dynamic]Draw_Call,
	draw_call_index:      int,
	current_draw_call:    ^Draw_Call,
	user_texture:         wgpu.Texture,
	atlas_texture:        wgpu.Texture,
	atlas_size:           f32,
	atlas_offset:         [2]f32,
	atlas_content_height: f32,
	paint:                Paint_Index,
	shape:                u32,
	xform:                u32,
	path_start:           u32,
	path_point:           [2]f32,
	affector:             Maybe(u32),
}

draw_call_count :: proc() -> int {
	return len(core.draw_calls)
}

renderer :: proc() -> ^Renderer {
	return &core.renderer
}

request_adapter_options :: proc() -> wgpu.RequestAdapterOptions {
	return wgpu.RequestAdapterOptions{powerPreference = .LowPower}
}

device_descriptor :: proc() -> wgpu.DeviceDescriptor {
	return wgpu.DeviceDescriptor {
		requiredFeatureCount = 1,
		requiredFeatures = ([^]wgpu.FeatureName)(&[?]wgpu.FeatureName{.VertexWritableStorage}),
	}
}

surface_configuration :: proc(
	device: wgpu.Device,
	adapter: wgpu.Adapter,
	surface: wgpu.Surface,
) -> wgpu.SurfaceConfiguration {
	caps := wgpu.SurfaceGetCapabilities(surface, adapter)
	core.renderer.surface_config = wgpu.SurfaceConfiguration {
		presentMode = caps.presentModes[0],
		alphaMode   = caps.alphaModes[0],
		device      = device,
		format      = .BGRA8Unorm, //caps.formats[0],
		usage       = {.RenderAttachment},
	}
	return core.renderer.surface_config
}

Platform :: struct {
	instance: wgpu.Instance,
	device: wgpu.Device,
	adapter: wgpu.Adapter,
	surface: wgpu.Surface,
	surface_config: wgpu.SurfaceConfiguration,
}

destroy_platform :: proc(self: ^Platform) {
	wgpu.SurfaceRelease(self.surface)
	wgpu.AdapterRelease(self.adapter)
	wgpu.DeviceRelease(self.device)
	wgpu.InstanceRelease(self.instance)
}

make_platform_sdl2glue :: proc(window: ^sdl2.Window) -> (platform: Platform) {
	platform.instance = wgpu.CreateInstance()
	if platform.instance == nil {
		fmt.eprintln("Failed to create instance!")
	}

	platform.surface = sdl2glue.GetSurface(platform.instance, window)
	if platform.surface == nil {
		fmt.eprintln("Failed to create surface!")
	}

	on_device :: proc "c" (
		status: wgpu.RequestDeviceStatus,
		device: wgpu.Device,
		message: cstring,
		userdata: rawptr,
	) {
		context = runtime.default_context()
		switch status {
		case .Success:
			(^Platform)(userdata).device = device
		case .Error:
			fmt.panicf("Unable to aquire device: %s", message)
		case .Unknown:
			panic("Unknown error")
		}
	}

	on_adapter :: proc "c" (
		status: wgpu.RequestAdapterStatus,
		adapter: wgpu.Adapter,
		message: cstring,
		userdata: rawptr,
	) {
		context = runtime.default_context()
		switch status {
		case .Success:
			(^Platform)(userdata).adapter = adapter
			info := wgpu.AdapterGetInfo(adapter)
			fmt.printfln("Using %v on %v", info.backendType, info.description)

			descriptor := device_descriptor()
			wgpu.AdapterRequestDevice(adapter, &descriptor, on_device, userdata)
		case .Error:
			fmt.panicf("Unable to acquire adapter: %s", message)
		case .Unavailable:
			panic("Adapter unavailable")
		case .Unknown:
			panic("Unknown error")
		}
	}

	wgpu.InstanceRequestAdapter(
		platform.instance,
		&{powerPreference = .LowPower},
		on_adapter,
		&platform,
	)
	platform.surface_config = surface_configuration(
		platform.device,
		platform.adapter,
		platform.surface,
	)

	width, height: i32
	sdl2.GetWindowSize(window, &width, &height)
	platform.surface_config.width = u32(width)
	platform.surface_config.height = u32(height)

	wgpu.SurfaceConfigure(platform.surface, &platform.surface_config)

	return
}

start_on_platform :: proc(platform: Platform) {
	start(platform.device, platform.surface)
}

start :: proc(device: wgpu.Device, surface: wgpu.Surface) {
	init_renderer_with_device_and_surface(&core.renderer, device, surface)

	core.atlas_size = f32(min(core.renderer.device_limits.maxTextureDimension2D, 8196))
	atlas_depth := f32(min(core.renderer.device_limits.maxTextureDimension3D, 4))
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

	make_default_font()

	core.start_time = time.now()
	core.frame_time = core.start_time
}

shutdown :: proc() {
	destroy_font(&core.default_font)
	delete(core.draw_calls)
	wgpu.TextureDestroy(core.atlas_texture)
	destroy_renderer(&core.renderer)
}

get_fps :: proc() -> f32 {
	return core.fps
}

reset_drawing :: proc() {
	clear(&core.renderer.shapes.data)
	clear(&core.renderer.paints.data)
	clear(&core.renderer.cvs.data)
	clear(&core.renderer.xforms.data)

	clear(&core.draw_calls)
	core.current_draw_call = nil
	core.draw_call_index = 0

	append(&core.renderer.paints.data, Paint{kind = .None})
	append(&core.renderer.shapes.data, Shape{kind = .None})

	append_draw_call()

	core.scissor_stack.height = 0
	core.matrix_stack.height = 0
	core.last_matrix = {}
	core.matrix_index = 0
	core.opacity = 1

	push_matrix()
}

new_frame :: proc() {
	t := time.now()
	core.delta_time = f32(time.duration_seconds(time.since(core.frame_time)))
	core.frame_time = time.now()

	since_last_second := time.since(core.last_second)
	if since_last_second >= time.Second {
		core.fps = f32(core.frames_this_second)
		core.frames_this_second = 0
		core.last_second = core.frame_time
	}
	core.frames_this_second += 1

	reset_drawing()

	set_font(DEFAULT_FONT)
}

run_time :: proc() -> f32 {
	return f32(time.duration_seconds(time.since(core.start_time)))
}

frame_time :: proc() -> f32 {
	return core.delta_time
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

copy_image_to_atlas :: proc(data: rawptr, width, height: int) -> Box {
	box := get_atlas_box([2]f32{f32(width), f32(height)})
	wgpu.QueueWriteTexture(
		core.renderer.queue,
		&{texture = core.atlas_texture, origin = {x = u32(box.lo.x), y = u32(box.lo.y)}},
		data,
		uint(width * height * 4),
		&{bytesPerRow = u32(box.hi.x - box.lo.x) * 4, rowsPerImage = u32(box.hi.y - box.lo.y)},
		&{
			width = u32(box.hi.x - box.lo.x),
			height = u32(box.hi.y - box.lo.y),
			depthOrArrayLayers = 1,
		},
	)
	wgpu.QueueSubmit(core.renderer.queue, {})
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

pop_stack :: proc(stack: ^Stack($T, $N), loc := #caller_location) -> T {
	assert(stack.height > 0, loc = loc)
	stack.height -= 1
	return stack.items[stack.height]
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
