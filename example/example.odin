package vgo_example

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:time"
import "vendor:sdl2"
import "vendor:wgpu"
import "vendor:wgpu/sdl2glue"

import ".."

adapter: wgpu.Adapter
device: wgpu.Device

main :: proc() {

	sdl2.Init(sdl2.INIT_VIDEO)
	defer sdl2.Quit()

	window := sdl2.CreateWindow("vgo example", 100, 100, 640, 480, {.SHOWN, .RESIZABLE})
	defer sdl2.DestroyWindow(window)

	instance := wgpu.CreateInstance()

	surface := sdl2glue.GetSurface(instance, window)

	on_device :: proc "c" (
		status: wgpu.RequestDeviceStatus,
		_device: wgpu.Device,
		message: cstring,
		userdata: rawptr,
	) {
		context = runtime.default_context()
		switch status {
		case .Success:
			device = _device
		case .Error:
			fmt.panicf("Unable to aquire device: %s", message)
		case .Unknown:
			panic("Unknown error")
		}
	}

	on_adapter :: proc "c" (
		status: wgpu.RequestAdapterStatus,
		_adapter: wgpu.Adapter,
		message: cstring,
		userdata: rawptr,
	) {
		context = runtime.default_context()
		switch status {
		case .Success:
			adapter = _adapter
			info := wgpu.AdapterGetInfo(adapter)
			fmt.printfln("Using %v on %v", info.backendType, info.description)
			wgpu.AdapterRequestDevice(
				adapter,
				&{
					requiredFeatureCount = 1,
					requiredFeatures = ([^]wgpu.FeatureName)(
						&[?]wgpu.FeatureName{.VertexWritableStorage},
					),
				},
				on_device,
			)
		case .Error:
			fmt.panicf("Unable to acquire adapter: %s", message)
		case .Unavailable:
			panic("Adapter unavailable")
		case .Unknown:
			panic("Unknown error")
		}
	}

	when false {
		adapters := wgpu.InstanceEnumerateAdapters(instance)
		on_adapter(.Success, adapters[1], nil, nil)
	} else {
		wgpu.InstanceRequestAdapter(
			instance,
			&{powerPreference = .LowPower, backendType = .OpenGL},
			on_adapter,
		)
	}

	window_width, window_height: i32
	sdl2.GetWindowSize(window, &window_width, &window_height)

	caps := wgpu.SurfaceGetCapabilities(surface, adapter)
	surface_config := wgpu.SurfaceConfiguration {
		width       = u32(window_width),
		height      = u32(window_height),
		presentMode = caps.presentModes[0],
		alphaMode   = caps.alphaModes[0],
		device      = device,
		format      = caps.formats[0],
		usage       = {.RenderAttachment},
	}
	wgpu.SurfaceConfigure(surface, &surface_config)

	vgo.start(device, surface, surface_config.format)
	defer vgo.done()

	font_24px, _ := vgo.load_font_from_image_and_json(
		"fonts/SF-Pro-Display-Regular-24px.png",
		"fonts/SF-Pro-Display-Regular-24px.json",
	)

	font_48px, _ := vgo.load_font_from_image_and_json(
		"fonts/SF-Pro-Display-Regular-48px.png",
		"fonts/SF-Pro-Display-Regular-48px.json",
	)

	icon_font, _ := vgo.load_font_from_image_and_json(
		"fonts/remixicon.png",
		"fonts/remixicon.json",
	)

	animate: bool = true
	animation_time: f32 = 0.1

	mouse_point: [2]f32
	canvas_size: [2]f32 = {f32(window_width), f32(window_height)}

	loop: for {
		time.sleep(time.Millisecond * 16)

		if animate {
			animation_time += vgo.frame_time()
		}

		event: sdl2.Event
		for sdl2.PollEvent(&event) {
			#partial switch event.type {
			case .KEYDOWN:
				if event.key.keysym.sym == .A {
					animate = !animate
				}
			case .MOUSEMOTION:
				mouse_point = {f32(event.motion.x), f32(event.motion.y)}
			case .QUIT:
				break loop
			case .WINDOWEVENT:
				if event.window.event == .RESIZED {
					window_width, window_height: i32
					sdl2.GetWindowSize(window, &window_width, &window_height)
					surface_config.width = u32(window_width)
					surface_config.height = u32(window_height)
					wgpu.SurfaceConfigure(surface, &surface_config)
					canvas_size = {f32(window_width), f32(window_height)}
				}
			}
		}

		vgo.new_frame()

		GRADIENT_COLORS :: [2]vgo.Color{vgo.BLUE, vgo.DEEP_BLUE}

		layout := vgo.Box{100, canvas_size - 100}
		cut_box :: proc(box: ^vgo.Box, size: f32) -> vgo.Box {
			if box.hi.y - box.lo.y < size {
				box.lo.y = 100
				box.lo.x += (box.hi.x - box.lo.x) * 0.5
			}
			box.lo.y += size
			result := vgo.Box{{box.lo.x, box.lo.y - size}, {box.lo.x + size, box.lo.y}}
			size := result.hi - result.lo
			result.lo += size * 0.25
			result.hi -= size * 0.25
			return result
		}
		layout_size := canvas_size.y / 5

		first_shape: u32
		{
			box := cut_box(&layout, layout_size)
			center := (box.lo + box.hi) / 2
			vgo.push_matrix()
			defer vgo.pop_matrix()
			vgo.translate(center)
			vgo.rotate(math.sin(animation_time * 2) * 0.15)
			vgo.translate(-center)
			vgo.fill_box(
				box,
				vgo.make_linear_gradient(
					{box.lo.x, box.hi.y},
					{box.hi.x, box.lo.y},
					GRADIENT_COLORS[0],
					GRADIENT_COLORS[1],
				),
				radius = {10, 30, 30, 10},
			)
		}

		{
			box := cut_box(&layout, layout_size)
			vgo.fill_circle(
				(box.lo + box.hi) / 2,
				(box.hi.x - box.lo.x) / 2,
				vgo.make_linear_gradient(
					{box.lo.x, box.hi.y},
					{box.hi.x, box.lo.y},
					GRADIENT_COLORS[0],
					GRADIENT_COLORS[1],
				),
			)
		}

		{
			box := cut_box(&layout, layout_size)
			radius := (box.hi - box.lo) / 2
			sides := 5
			center := (box.lo + box.hi) / 2
			vgo.push_matrix()
			defer vgo.pop_matrix()
			vgo.translate(center)
			vgo.rotate(math.sin(animation_time * 1.75) * 0.2)
			vgo.translate(-center)
			vgo.begin_path()
			vgo.move_to(box.lo)
			vgo.quadratic_bezier_to({box.lo.x, box.hi.y}, box.hi)
			vgo.quadratic_bezier_to({box.hi.x, box.lo.y}, box.lo)
			box.lo += 15
			box.hi -= 15
			vgo.move_to(box.lo)
			vgo.quadratic_bezier_to({box.lo.x, box.hi.y}, box.hi)
			vgo.quadratic_bezier_to({box.hi.x, box.lo.y}, box.lo)
			vgo.fill_path(
				vgo.make_linear_gradient(
					{box.lo.x, box.hi.y},
					{box.hi.x, box.lo.y},
					GRADIENT_COLORS[0],
					GRADIENT_COLORS[1],
				),
			)
		}

		{
			box := cut_box(&layout, layout_size)
			radius := (box.hi - box.lo) / 2
			sides := 5
			center := (box.lo + box.hi) / 2
			vgo.push_matrix()
			defer vgo.pop_matrix()
			vgo.translate(center)
			vgo.rotate(math.sin(animation_time))
			vgo.translate(-center)
			vgo.begin_path()
			for i := 0; i <= sides; i += 1 {
				a := math.TAU * (f32(i) / f32(sides)) + animation_time * 0.5
				p := center + [2]f32{math.cos(a), math.sin(a)} * radius
				if i == 0 {
					vgo.move_to(p)
				} else {
					b :=
						math.TAU * (f32(i) / f32(sides)) -
						(math.TAU / f32(sides * 2)) +
						animation_time * 0.5
					vgo.quadratic_bezier_to(
						center + [2]f32{math.cos(b), math.sin(b)} * (radius - 20),
						p,
					)
				}
			}
			vgo.fill_path(
				vgo.make_linear_gradient(
					{box.lo.x, box.hi.y},
					{box.hi.x, box.lo.y},
					GRADIENT_COLORS[0],
					GRADIENT_COLORS[1],
				),
			)
		}

		// Text transforms
		{
			box := cut_box(&layout, layout_size)
			center := (box.lo + box.hi) / 2
			vgo.push_matrix()
			defer vgo.pop_matrix()
			vgo.translate(center)
			vgo.rotate(math.sin(animation_time) * 0.08)
			vgo.scale(1.0 + math.sin(animation_time * 0.5) * 0.2)
			vgo.translate(-center)
			line_limit := f32(400)
			text := "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi lobortis nunc quis lacus dictum, vel commodo eros bibendum."
			size := f32(20)
			text_size := vgo.measure_text(text, font_48px, size, line_limit = line_limit)
			vgo.fill_text(
				text,
				font_24px,
				center + {0, -text_size.y},
				size,
				vgo.make_radial_gradient(center, 200, GRADIENT_COLORS[0], GRADIENT_COLORS[1]),
				line_limit = line_limit,
			)
		}

		vgo.fill_text("Press 'A' to play/pause animation", font_24px, {canvas_size.x / 2 - 130, canvas_size.y - 20}, 20, vgo.Color(255))

		vgo.present()

		free_all(context.temp_allocator)
	}
}
