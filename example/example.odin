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

	window := sdl2.CreateWindow("vgo example", 0, 0, 640, 480, {.SHOWN, .RESIZABLE})
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

		GRADIENT_COLORS :: [2]vgo.Color{
			{255, 202, 32, 255},
			{255, 110, 32, 255},
		}

		{
			box := vgo.Box{100, 180}
			vgo.fill_box(box, vgo.Paint{kind = .Distance_Field}, {10, 30, 30, 10})
		}

		{
			box := vgo.Box{{100, 200}, {180, 280}}
			vgo.fill_circle((box.lo + box.hi) / 2, 40, vgo.Paint{kind = .Distance_Field})
		}

		{
			box := vgo.Box{{100, 300}, {180, 380}}
			center := (box.lo + box.hi) / 2
			radius := (box.hi - box.lo) / 2
			sides := 5
			vgo.begin_path()
			// for i := sides; i >= 0; i -= 1 {
			// 	a := math.TAU * (f32(i) / f32(sides)) + animation_time * 0.5
			// 	p := center + [2]f32{math.cos(a), math.sin(a)} * radius
			// 	if i == 5 {
			// 		vgo.move_to(p)
			// 	} else {
			// 		b := math.TAU * (f32(i) / f32(sides)) - (math.TAU / f32(sides * 2)) + animation_time * 0.5
			// 		vgo.quadratic_bezier_to(center + [2]f32{math.cos(b), math.sin(b)} * (radius - 20), p)
			// 	}
			// }
			vgo.move_to(box.lo)
			vgo.quadratic_bezier_to({box.lo.x, box.hi.y}, box.hi + {-1, 0})
			vgo.quadratic_bezier_to({box.hi.x, box.lo.y}, box.lo)
			vgo.fill_path(vgo.Paint{kind = .Distance_Field})
		}

		vgo.present()

		free_all(context.temp_allocator)
	}
}
