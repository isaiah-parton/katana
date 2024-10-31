package vgo_example

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:math/ease"
import "core:math/linalg"
import "core:time"
import "vendor:sdl2"
import "vendor:wgpu"
import "vendor:wgpu/sdl2glue"

import ".."

adapter: wgpu.Adapter
device: wgpu.Device

LOREM_IPSUM :: `Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nulla euismod venenatis augue ut vehicula. Sed nec lorem auctor, scelerisque magna nec, efficitur nisl. Mauris in urna vitae lorem fermentum facilisis. Nam sodales libero eleifend eros viverra, vel facilisis quam faucibus. Mauris tortor metus, fringilla id tempus efficitur, suscipit a diam. Quisque pretium nec tellus vel auctor. Quisque vel auctor arcu. Suspendisse malesuada sem eleifend, fermentum lectus non, lobortis arcu. Quisque a elementum nibh, ac ornare lectus. Suspendisse ac felis vestibulum, feugiat arcu vel, commodo ligula.

Nam in nulla justo. Praesent eget neque pretium, consectetur purus sit amet, placerat nulla. Vestibulum lacinia enim vel egestas iaculis. Nulla congue quam nulla, sit amet placerat nunc vulputate nec. Vestibulum ante felis, pellentesque in nibh ac, tempor faucibus mi. Duis id arcu sit amet lorem tempus volutpat sit amet pretium justo. Integer tincidunt felis enim, sed ornare mi pellentesque a. Suspendisse potenti. Quisque blandit posuere ipsum, vitae vestibulum mauris placerat a. Nunc sed ante gravida, viverra est in, hendrerit est. Phasellus libero augue, posuere eu bibendum ut, semper non justo. Vestibulum maximus, nulla sed gravida porta, tellus erat dapibus augue, sed lacinia augue sapien eget velit. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus.

Aliquam vel velit eu purus aliquet commodo id sit amet erat. Vivamus imperdiet magna in finibus ultrices. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Pellentesque euismod facilisis dui. Fusce quam mi, auctor condimentum est id, volutpat aliquet sapien. Nam mattis risus nunc, sed efficitur odio interdum non. Aenean ornare libero ex, sollicitudin accumsan dolor congue vitae. Maecenas nibh urna, vehicula in felis et, ornare porttitor nisi.`

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
		case .Success: device = _device
		case .Error: fmt.panicf("Unable to aquire device: %s", message)
		case .Unknown: panic("Unknown error")
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

			descriptor := vgo.device_descriptor()
			wgpu.AdapterRequestDevice(
				adapter,
				&descriptor,
				on_device,
			)
		case .Error: fmt.panicf("Unable to acquire adapter: %s", message)
		case .Unavailable: panic("Adapter unavailable")
		case .Unknown: panic("Unknown error")
		}
	}

	wgpu.InstanceRequestAdapter(instance, &{powerPreference = .LowPower}, on_adapter)

	window_width, window_height: i32
	sdl2.GetWindowSize(window, &window_width, &window_height)

	surface_config := vgo.surface_configuration(device, adapter, surface)
	surface_config.width = u32(window_width)
	surface_config.height = u32(window_height)
	wgpu.SurfaceConfigure(surface, &surface_config)

	vgo.start(device, surface, surface_config.format)
	defer vgo.shutdown()

	// Load some fonts
	light_font, _ := vgo.load_font_from_image_and_json(
		"fonts/KumbhSans-Regular-16px.png",
		"fonts/KumbhSans-Regular-16px.json",
	)
	regular_font, _ := vgo.load_font_from_image_and_json(
		"fonts/KumbhSans-Regular-32px.png",
		"fonts/KumbhSans-Regular-32px.json",
	)
	icon_font, _ := vgo.load_font_from_image_and_json(
		"fonts/remixicon.png",
		"fonts/remixicon.json",
	)

	//
	animate: bool = true
	animation_time: f32 = 0.1
	page: int
	PAGE_COUNT :: 4
	mouse_point: [2]f32
	canvas_size: [2]f32 = {f32(window_width), f32(window_height)}

	// Frame loop
	loop: for {
		time.sleep(time.Millisecond * 10)

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
			vgo.fill_glyph(
				vgo.get_font_glyph(regular_font, 'd') or_else panic(""),
				128,
				100,
				vgo.WHITE,
				8.0,
			)

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
					{10, 30, 30, 10},
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
				vgo.quad_bezier_to({box.lo.x + 30, box.hi.y}, {box.lo.x + 50, box.lo.y + 30})
				vgo.quad_bezier_to({box.hi.x, box.hi.y}, {box.hi.x - 20, box.hi.y})
				vgo.quad_bezier_to({box.hi.x - 30, box.hi.y - 40}, {box.hi.x - 20, box.lo.y})
				vgo.quad_bezier_to({box.lo.x + 20, box.lo.y + 50}, box.lo)
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
						vgo.quad_bezier_to(
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
				vgo.arc(
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

				s := math.sin(animation_time * 3) * radius * 1.5
				vgo.stroke_cubic_bezier(
					center + {-radius, 0},
					center + {-radius * 0.4, -s},
					center + {radius * 0.4, s},
					center + {radius, 0},
					4.0,
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
				vgo.rotate(
					math.TAU *
					ease.cubic_in_out(max(math.mod(animation_time, 1.0) - 0.8, 0.0) * 5.0),
				)
				vgo.fill_glyph(
					icon_font.glyphs[int(animation_time + 0.1) % len(icon_font.glyphs)],
					size,
					{-radius, -radius + icon_font.descend * size},
					vgo.make_linear_gradient(
						-radius,
						radius,
						GRADIENT_COLORS[0],
						GRADIENT_COLORS[1],
					),
					pixel_range = (size / icon_font.size) * icon_font.distance_range,
				)
			}
		case 1:
			box := layout.bounds

			vgo.push_scissor(vgo.make_box(box, 0))
			defer vgo.pop_scissor()
			vgo.push_scissor(vgo.make_circle(mouse_point, 250))
			defer vgo.pop_scissor()

			// vgo.fill_box(box, vgo.BLACK)
			text_size := f32(24 + clamp(math.sin(animation_time), 0, 0.5) * 24)
			vgo.fill_text(
				LOREM_IPSUM,
				regular_font,
				text_size,
				box.lo,
				options = {wrap = .Word, max_width = box.hi.x - box.lo.x},
				paint = vgo.make_linear_gradient(
					box.lo,
					box.hi,
					GRADIENT_COLORS[0],
					GRADIENT_COLORS[1],
				),
			)
		case 2:
			{
				text := "Rotating ünicode téxt!"
				text_size := f32(48)
				center := canvas_size / 2
				size := vgo.measure_text(text, regular_font, text_size)

				vgo.push_matrix()
				defer vgo.pop_matrix()
				vgo.translate(center)
				vgo.rotate(animation_time * 0.1)
				vgo.fill_text(
					text,
					regular_font,
					text_size,
					-size / 2 + 4,
					paint = vgo.GRAY(0.025),
				)
				vgo.fill_text(text, regular_font, text_size, -size / 2, paint = vgo.WHITE)
			}
			{
				box := layout.bounds

				text := "Stretched text"
				text_size := f32(48)
				center := canvas_size / 2 + {0, -200}
				size := vgo.measure_text(text, regular_font, text_size)

				vgo.push_matrix()
				defer vgo.pop_matrix()
				vgo.translate(center)
				vgo.scale({1.0 + math.sin(animation_time) * 0.5, 1.0})
				vgo.fill_text(text, regular_font, text_size, -size / 2, paint = vgo.WHITE)
			}
			{
				box := layout.bounds

				text := "Dynamic text size"
				text_size := f32(48) + math.sin(animation_time) * 24
				center := canvas_size / 2 + {0, 200}
				size := vgo.measure_text(text, regular_font, text_size)

				vgo.fill_text(text, regular_font, text_size, center - size / 2, paint = vgo.WHITE)
			}
		case 3:
			box := layout.bounds
			left_box := vgo.Box{box.lo, {(box.lo.x + box.hi.x) / 2, box.hi.y}}
			right_box := vgo.Box{{(box.lo.x + box.hi.x) / 2, box.lo.y}, box.hi}
			vgo.fill_box(
				left_box,
				paint = vgo.make_linear_gradient(
					left_box.lo,
					left_box.hi,
					GRADIENT_COLORS[0],
					GRADIENT_COLORS[1],
				),
			)
			left_box.lo += 20
			right_box.lo += 20
			left_box.hi -= 20
			right_box.hi -= 20
			vgo.fill_text(
				LOREM_IPSUM,
				light_font,
				16,
				left_box.lo,
				{max_width = left_box.hi.x - left_box.lo.x, wrap = .Word},
				vgo.BLACK,
			)

			vgo.fill_text(
				LOREM_IPSUM,
				light_font,
				16,
				right_box.lo,
				{max_width = right_box.hi.x - right_box.lo.x, wrap = .Word},
				vgo.make_linear_gradient(
					right_box.lo,
					right_box.hi,
					GRADIENT_COLORS[0],
					GRADIENT_COLORS[1],
				),
			)
		}

		vgo.fill_text(
			fmt.tprintf("FPS: %.0f", vgo.get_fps()),
			light_font,
			16,
			{},
			paint = vgo.GREEN,
		)

		{
			text := "[A] play/pause animation\n[Right] next page\n[Left] previous page"
			text_size := f32(16)
			size := vgo.measure_text(text, light_font, text_size)
			vgo.fill_text(
				text,
				light_font,
				text_size,
				{0, canvas_size.y - size.y},
				paint = vgo.Color(255),
			)
		}

		vgo.present()

		free_all(context.temp_allocator)
	}
}
