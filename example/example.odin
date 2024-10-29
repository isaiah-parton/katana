package vgo_example

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/ease"
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
	page: int
	PAGE_COUNT :: 3

	mouse_point: [2]f32
	canvas_size: [2]f32 = {f32(window_width), f32(window_height)}

	loop: for {
		// time.sleep(time.Millisecond * 16)

		if animate {
			animation_time += vgo.frame_time()
		}

		event: sdl2.Event
		for sdl2.PollEvent(&event) {
			#partial switch event.type {
			case .KEYDOWN:
				#partial switch event.key.keysym.sym {
				case .A:
					animate = !animate
				case .LEFT:
					page -= 1
					if page < 0 do page = PAGE_COUNT - 1
				case .RIGHT:
					page = (page + 1) % PAGE_COUNT
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

		Layout :: struct {
			bounds, box: vgo.Box,
		}
		layout := Layout {
			bounds = {100, canvas_size - 100},
			box    = {100, canvas_size - 100},
		}

		COLUMNS :: 2
		ROWS :: 4
		SIZE :: 40

		get_box :: proc(layout: ^Layout) -> vgo.Box {
			size := (layout.bounds.hi - layout.bounds.lo) / [2]f32{COLUMNS, ROWS}
			if layout.box.lo.y + size.y > layout.box.hi.y {
				layout.box.lo.x += size.x
				layout.box.lo.y = layout.bounds.lo.y
			}
			result := vgo.Box{layout.box.lo, layout.box.lo + size}
			layout.box.lo.y += size.y
			return result
		}

		switch page {
		case 0:
			{
				container := get_box(&layout)
				center := (container.lo + container.hi) / 2
				radius := f32(SIZE)
				box := vgo.Box{center - radius, center + radius}

				vgo.push_matrix()
				defer vgo.pop_matrix()
				vgo.translate(center)
				vgo.rotate(math.sin(animation_time * 5) * 0.15)
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
				container := get_box(&layout)
				center := (container.lo + container.hi) / 2
				radius := f32(SIZE)

				vgo.fill_circle(
					center,
					radius,
					vgo.make_linear_gradient(
						center - radius,
						center + radius,
						GRADIENT_COLORS[0],
						GRADIENT_COLORS[1],
					),
				)
			}

			{
				container := get_box(&layout)
				center := (container.lo + container.hi) / 2
				radius := f32(SIZE)
				box := vgo.Box{center - radius, center + radius}

				vgo.push_matrix()
				defer vgo.pop_matrix()
				vgo.translate(center)
				vgo.rotate(math.sin(animation_time * 1.75) * 0.2)
				vgo.translate(-center)
				vgo.begin_path()
				vgo.move_to(box.lo)
				vgo.quadratic_bezier_to({box.lo.x, box.hi.y}, box.hi)
				vgo.quadratic_bezier_to({box.hi.x, box.lo.y}, box.lo)
				s := f32(10) * math.sin(animation_time * 3)
				box.lo += 15 + s
				box.hi -= 15 - s
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
				container := get_box(&layout)
				center := (container.lo + container.hi) / 2
				radius := f32(SIZE)

				sides := 5

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
						center - radius,
						center + radius,
						GRADIENT_COLORS[0],
						GRADIENT_COLORS[1],
					),
				)
			}

			// Arc
			{
				container := get_box(&layout)
				center := (container.lo + container.hi) / 2
				radius := f32(SIZE)

				t := animation_time * 3
				vgo.draw_arc(
					center,
					t,
					t + math.TAU * 0.75,
					radius - 4,
					radius,
					vgo.make_linear_gradient(
						center - radius,
						center + radius,
						GRADIENT_COLORS[0],
						GRADIENT_COLORS[1],
					),
				)
			}

			// Bezier stroke
			{
				container := get_box(&layout)
				center := (container.lo + container.hi) / 2
				radius := f32(SIZE)

				s := math.sin(animation_time * 3) * radius
				vgo.stroke_cubic_bezier(
					center + {-radius, 0},
					center + {-radius * 0.4, -s},
					center + {radius * 0.4, s},
					center + {radius, 0},
					2.0,
					vgo.make_linear_gradient(
						center - radius,
						center + radius,
						GRADIENT_COLORS[0],
						GRADIENT_COLORS[1],
					),
				)
			}

			// Text transforms
			{
				container := get_box(&layout)
				center := (container.lo + container.hi) / 2
				radius := f32(SIZE)

				t := abs(math.cos(animation_time * 8)) * 0.7
				vgo.fill_pie(
					center,
					t,
					-t,
					radius,
					vgo.make_linear_gradient(
						center - radius,
						center + radius,
						GRADIENT_COLORS[0],
						GRADIENT_COLORS[1],
					),
				)
			}

			// Icons
			{
				container := get_box(&layout)
				center := (container.lo + container.hi) / 2
				radius := f32(SIZE + 5)
				size := radius * 2

				vgo.push_matrix()
				defer vgo.pop_matrix()
				vgo.translate(center)
				vgo.rotate(math.TAU * ease.cubic_in_out(max(math.mod(animation_time, 1.0) - 0.8, 0.0) * 5.0))
				vgo.draw_glyph(
					icon_font,
					icon_font.glyphs[int(animation_time + 0.1) % len(icon_font.glyphs)],
					{-radius, -radius + icon_font.descend * size},
					size,
					vgo.make_linear_gradient(
						-radius,
						radius,
						GRADIENT_COLORS[0],
						GRADIENT_COLORS[1],
					),
				)
			}
		case 1:
			box := layout.bounds
			vgo.push_scissor(box, vgo.add_shape(vgo.make_box(box, 0)))
			defer vgo.pop_scissor()
			vgo.fill_text(
				`Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nulla euismod venenatis augue ut vehicula. Sed nec lorem auctor, scelerisque magna nec, efficitur nisl. Mauris in urna vitae lorem fermentum facilisis. Nam sodales libero eleifend eros viverra, vel facilisis quam faucibus. Mauris tortor metus, fringilla id tempus efficitur, suscipit a diam. Quisque pretium nec tellus vel auctor. Quisque vel auctor arcu. Suspendisse malesuada sem eleifend, fermentum lectus non, lobortis arcu. Quisque a elementum nibh, ac ornare lectus. Suspendisse ac felis vestibulum, feugiat arcu vel, commodo ligula.

Nam in nulla justo. Praesent eget neque pretium, consectetur purus sit amet, placerat nulla. Vestibulum lacinia enim vel egestas iaculis. Nulla congue quam nulla, sit amet placerat nunc vulputate nec. Vestibulum ante felis, pellentesque in nibh ac, tempor faucibus mi. Duis id arcu sit amet lorem tempus volutpat sit amet pretium justo. Integer tincidunt felis enim, sed ornare mi pellentesque a. Suspendisse potenti. Quisque blandit posuere ipsum, vitae vestibulum mauris placerat a. Nunc sed ante gravida, viverra est in, hendrerit est. Phasellus libero augue, posuere eu bibendum ut, semper non justo. Vestibulum maximus, nulla sed gravida porta, tellus erat dapibus augue, sed lacinia augue sapien eget velit. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus.

Aliquam vel velit eu purus aliquet commodo id sit amet erat. Vivamus imperdiet magna in finibus ultrices. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Pellentesque euismod facilisis dui. Fusce quam mi, auctor condimentum est id, volutpat aliquet sapien. Nam mattis risus nunc, sed efficitur odio interdum non. Aenean ornare libero ex, sollicitudin accumsan dolor congue vitae. Maecenas nibh urna, vehicula in felis et, ornare porttitor nisi.

Donec elit purus, lobortis ut porttitor nec, elementum eu metus. Aliquam erat volutpat. Morbi dictum libero sed lorem malesuada, a egestas enim viverra. Cras eget euismod turpis. Aenean auctor nisl vel tristique consectetur. Sed vitae est id velit vestibulum tempus. Nullam sodales elit nibh, id hendrerit enim hendrerit in. Aenean sed sodales enim. Etiam a purus nec mi tempus fermentum non in turpis. Duis ullamcorper, tortor at euismod egestas, turpis justo eleifend dui, eu hendrerit nunc ligula et felis. Phasellus nec felis in nisi scelerisque fermentum sit amet sit amet justo. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Ut quam mi, sodales et urna eget, egestas hendrerit magna. Aenean ac nulla vitae nibh molestie dictum. Cras sapien mauris, dignissim quis metus a, semper dignissim dui.

Phasellus tempor hendrerit nisi eu gravida. Donec fringilla, justo nec suscipit volutpat, sapien ante convallis velit, vitae fermentum risus eros ac sapien. Nullam sit amet imperdiet dolor. Nullam dapibus eleifend lorem dapibus iaculis. Nulla euismod diam nec pretium rutrum. Duis tempus gravida tempor. Nulla sit amet dapibus tellus. Nunc elementum vitae purus at lacinia. Curabitur a finibus quam, ut auctor magna. Cras commodo viverra nulla, sit amet rutrum massa. Nunc pharetra tortor vel dui egestas, sed euismod lacus tempor. Curabitur eu erat a odio tincidunt fermentum vitae quis turpis.`,
				font_24px,
				box.lo,
				24 + clamp(math.sin(animation_time), 0, 0.5) * 20,
				vgo.make_radial_gradient(mouse_point, 500, vgo.WHITE, vgo.fade(vgo.WHITE, 0.0)),
				line_limit = box.hi.x - box.lo.x,
			)
		case 2:
			{
				text := "Rotating ünicode téxt!"
				text_size := f32(48)
				center := canvas_size / 2
				size := vgo.measure_text(text, font_48px, text_size)

				vgo.push_matrix()
				defer vgo.pop_matrix()
				vgo.translate(center)
				vgo.rotate(animation_time * 2)
				vgo.fill_text(text, font_48px, -size / 2, text_size, vgo.GOLD)
			}
			{
				text := "Scaling text"
				text_size := f32(48)
				center := canvas_size / 2 + {-canvas_size.x / 3, 0}
				size := vgo.measure_text(text, font_48px, text_size)

				vgo.push_matrix()
				defer vgo.pop_matrix()
				vgo.translate(center)
				vgo.scale({1.0 + math.sin(animation_time) * 0.4, 1.0})
				vgo.fill_text(text, font_48px, -size / 2, text_size, vgo.GOLD)
			}
		}

		vgo.fill_text(fmt.tprintf("FPS: %.0f", vgo.get_fps()), font_24px, 0, 20, vgo.GREEN)

		{
			text := "[A] play/pause animation\n[Right] next page\n[Left] previous page"
			text_size := f32(24)
			size := vgo.measure_text(text, font_24px, text_size)
			vgo.fill_text(
				text,
				font_24px,
				{0, canvas_size.y - size.y},
				text_size,
				vgo.Color(255),
			)
		}

		vgo.present()

		free_all(context.temp_allocator)
	}
}
