package katana

import "base:runtime"
import "core:fmt"
import "core:slice"
import "core:time"
import "vendor:glfw"
import "vendor:wgpu"
import "vendor:wgpu/glfwglue"

// @(private)
core: Core

@(private)
Core :: struct {
	renderer:            Renderer,
	clear_color:         Color,
	start_time:          time.Time,
	frame_time:          time.Time,
	frames_this_second:  int,
	last_second:         time.Time,
	delta_time:          f32,
	fps:                 f32,
	matrix_stack:        Stack(Matrix, 128),
	current_matrix:      ^Matrix,
	last_matrix:         Matrix,
	matrix_index:        u32,
	default_font:        Font,
	current_font:        Font,
	fallback_font:       Font,
	scissor_stack:       Stack(Scissor, 32),
	scissor_stack_stack: Stack(Stack(Scissor, 32), 8), // bruh
	disable_scissor:     bool,
	opacity:             f32,
	draw_calls:          [dynamic]Draw_Call,
	draw_call_index:     int,
	current_draw_call:   ^Draw_Call,
	user_texture:        wgpu.Texture,
	font_atlas:          Atlas,
	paint:               Paint_Index,
	shape:               u32,
	xform:               u32,
	path_start:          u32,
	path_point:          [2]f32,
	affector:            Maybe(u32),
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

set_clear_color :: proc(color: Color) {
	core.clear_color = color
}

// **Create a SurfaceConfiguration**
//
// It seems that if this is set to `.Fifo`, the draw time decreases, but so does responsiveness in interactive programs (UI seems to lag one or two frames). `.Immediate` seems to offer the smoothest updates.
surface_configuration :: proc(
	device: wgpu.Device,
	adapter: wgpu.Adapter,
	surface: wgpu.Surface,
	presentMode: wgpu.PresentMode = .Immediate,
) -> (
	config: wgpu.SurfaceConfiguration,
	ok: bool,
) {
	assert(device != nil)
	assert(adapter != nil)
	assert(surface != nil)
	caps, status := wgpu.SurfaceGetCapabilities(surface, adapter)
	if status == .Error {
		return
	}
	// Prefer non-SRGB formats 👹
	slice.sort_by(caps.formats[:caps.formatCount], proc(i, j: wgpu.TextureFormat) -> bool {
		if i == j {
			return false
		}
		return j == .BGRA8UnormSrgb || j == .RGBA8UnormSrgb
	})
	config = wgpu.SurfaceConfiguration {
		device      = device,
		presentMode = presentMode,
		alphaMode   = .Auto,
		format      = caps.formats[0] if caps.formatCount > 0 else .BGRA8Unorm,
		usage       = {.RenderAttachment},
	}
	core.renderer.surface_config = config
	ok = true
	return
}

Platform :: struct {
	instance:       wgpu.Instance,
	device:         wgpu.Device,
	adapter:        wgpu.Adapter,
	surface:        wgpu.Surface,
	surface_config: wgpu.SurfaceConfiguration,
}

destroy_platform :: proc(self: ^Platform) {
	wgpu.SurfaceRelease(self.surface)
	wgpu.AdapterRelease(self.adapter)
	wgpu.DeviceRelease(self.device)
	wgpu.InstanceRelease(self.instance)
}

platform_get_adapter_and_device :: proc(
	platform: ^Platform,
	power_preference: wgpu.PowerPreference = .LowPower,
) {
	on_device :: proc "c" (
		status: wgpu.RequestDeviceStatus,
		device: wgpu.Device,
		message: string,
		userdata1: rawptr,
		userdata2: rawptr,
	) {
		context = runtime.default_context()
		switch status {
		case .InstanceDropped:
			panic("WGPU instance was dropped!")
		case .Success:
			(^Platform)(userdata1).device = device
		case .Error:
			fmt.panicf("Unable to aquire device: %s", message)
		case .Unknown:
			panic("Unknown error")
		}
	}

	on_adapter :: proc "c" (
		status: wgpu.RequestAdapterStatus,
		adapter: wgpu.Adapter,
		message: string,
		userdata1: rawptr,
		userdata2: rawptr,
	) {
		context = runtime.default_context()
		switch status {
		case .InstanceDropped:
			panic("WGPU instance was dropped!")
		case .Success:
			(^Platform)(userdata1).adapter = adapter
			info, status := wgpu.AdapterGetInfo(adapter)
			if status == .Success {
				fmt.printfln("Using %v on %v", info.backendType, info.description)
			} else {
				fmt.println("Could not get adapter info!")
			}

			descriptor := device_descriptor()
			wgpu.AdapterRequestDevice(
				adapter,
				&descriptor,
				{callback = on_device, userdata1 = userdata1},
			)
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
		&{powerPreference = power_preference, compatibleSurface = platform.surface},
		{callback = on_adapter, userdata1 = platform},
	)
}

make_platform_glfwglue :: proc(window: glfw.WindowHandle) -> (platform: Platform) {
	platform.instance = wgpu.CreateInstance() // &{nextInChain = &wgpu.InstanceExtras{sType = .InstanceExtras, backends = {.GL}}},

	if platform.instance == nil {
		panic("Failed to create instance!")
	}

	platform.surface = glfwglue.GetSurface(platform.instance, window)
	if platform.surface == nil {
		panic("Failed to create surface!")
	}

	platform_get_adapter_and_device(&platform)

	platform.surface_config, _ = surface_configuration(
		platform.device,
		platform.adapter,
		platform.surface,
	)

	width, height := glfw.GetWindowSize(window)
	platform.surface_config.width = u32(width)
	platform.surface_config.height = u32(height)

	wgpu.SurfaceConfigure(platform.surface, &platform.surface_config)

	return
}

start_on_platform :: proc(platform: Platform) {
	start(platform.device, platform.surface, platform.surface_config)
}

start :: proc(
	device: wgpu.Device,
	surface: wgpu.Surface,
	surface_config: wgpu.SurfaceConfiguration,
) {
	core.renderer.surface_config = surface_config
	init_renderer_with_device_and_surface(&core.renderer, device, surface)

	atlas_init(&core.font_atlas)

	make_default_font()

	core.start_time = time.now()
	core.frame_time = core.start_time
}

shutdown :: proc() {
	destroy_font(&core.default_font)
	delete(core.draw_calls)
	atlas_uninit(&core.font_atlas)
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

set_size :: proc(width, height: i32) {
	if core.renderer.surface_config.width == u32(width) &&
	   core.renderer.surface_config.height == u32(height) {
		return
	}
	core.renderer.surface_config.width = u32(width)
	core.renderer.surface_config.height = u32(height)
	wgpu.SurfaceConfigure(core.renderer.surface, &core.renderer.surface_config)
}

get_size :: proc() -> [2]f32 {
	return [2]f32 {
		f32(core.renderer.surface_config.width),
		f32(core.renderer.surface_config.height),
	}
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


Stack :: struct($T: typeid, $N: int) {
	items:  [N]T,
	height: int,
}

push_stack :: proc(stack: ^Stack($T, $N), item: T, loc := #caller_location) -> bool {
	assert(stack.height < N, loc = loc)
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

