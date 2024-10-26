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

	TEXT_SIZES :: [?]f32{12, 14, 16, 18, 20, 24, 28, 36, 42, 48, 56, 64, 72, 96, 112, 144}

	canvas_size: [2]f32 = {f32(window_width), f32(window_height)}

	loop: for {
		time.sleep(time.Millisecond * 16)

		event: sdl2.Event
		for sdl2.PollEvent(&event) {
			#partial switch event.type {
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

		vgo.fill_text(
			fmt.tprintf("FPS: %.1f\nwow^", vgo.get_fps()),
			font_24px,
			0,
			20,
			vgo.Color{0, 255, 0, 255},
		)

		shape := vgo.make_pie({100, 200}, 0, 2, 50)
		shape.outline = .Glow
		shape.width = 20
		vgo.draw_shape(shape, vgo.Color(255))

		box := vgo.Box{{120, 400}, {230, 430}}
		vgo.fill_box(box, vgo.make_linear_gradient(
			box.lo,
			{box.lo.x, box.hi.y},
			vgo.fade({20, 21, 24, 255}, 0.25),
			vgo.fade({20, 21, 24, 255}, 0.1),
		), radius = 5)
		vgo.stroke_box(
			box,
			1,
			vgo.make_linear_gradient(
				box.lo,
				{box.lo.x, box.hi.y},
				vgo.fade({20, 21, 24, 255}, 1),
				vgo.fade({20, 21, 24, 255}, 0),
			), radius = 5,
		)

		vgo.fill_pie(
			canvas_size / 2,
			math.PI / 2,
			math.PI / 2 + vgo.get_seconds() * 0.5,
			50,
			vgo.Color{255, 0, 0, 50},
		)
		vgo.stroke_pie(
			canvas_size / 2,
			math.PI / 2,
			math.PI / 2 + vgo.get_seconds() * 0.5,
			50,
			1,
			vgo.Color{255, 0, 0, 255},
		)
		vgo.draw_check(canvas_size / 2, 10, 255)
		vgo.draw_spinner(canvas_size / 2 + {0, 200}, 10, 255)
		vgo.draw_cubic_bezier(100, {200, 100}, {200, 200}, {300, 200}, 1, {255, 0, 255, 255})

		vgo.present()

		free_all(context.temp_allocator)
	}
}
