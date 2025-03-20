package katana_example

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:math/ease"
import "core:math/linalg"
import "core:os"
import "core:path/filepath"
import "core:time"
import "vendor:sdl2"
import "vendor:stb/image"
import "vendor:wgpu"
import "vendor:wgpu/sdl2glue"

import kn "../katana"

adapter: wgpu.Adapter
device: wgpu.Device

POEM :: `He clasps the crag with crooked hands;
Close to the sun in lonely lands,
Ring'd with the azure world, he stands.
The wrinkled sea beneath him crawls;
He watches from his mountain walls,
And like a thunderbolt he falls.`


LOREM_IPSUM :: `Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nulla euismod venenatis augue ut vehicula. Sed nec lorem auctor, scelerisque magna nec, efficitur nisl. Mauris in urna vitae lorem fermentum facilisis. Nam sodales libero eleifend eros viverra, vel facilisis quam faucibus.`

SAMPLE_TEXT :: "The quick brown fox jumps over the lazy dog."

main :: proc() {
	os.set_current_directory(#directory)

	sdl2.Init(sdl2.INIT_VIDEO)
	defer sdl2.Quit()

	window := sdl2.CreateWindow("vgo example", 100, 100, 1200, 800, {.SHOWN, .RESIZABLE})
	defer sdl2.DestroyWindow(window)

	window_width, window_height: i32
	sdl2.GetWindowSize(window, &window_width, &window_height)

	platform := kn.make_platform_sdl2glue(window)
	defer kn.destroy_platform(&platform)

	kn.start_on_platform(platform)
	defer kn.shutdown()

	// Load some fonts
	font, _ := kn.load_font_from_files("fonts/Lexend-Medium.png", "fonts/Lexend-Medium.json")
	icon_font, _ := kn.load_font_from_files("fonts/icons.png", "fonts/icons.json")

	//
	limit_fps: bool = true
	animate: bool = true
	enable_glyph_gamma_correction: bool = true
	animation_time: f32 = 0.1

	mouse_point: [2]f32
	canvas_size: [2]f32 = {f32(window_width), f32(window_height)}
	frame_time: f32
	last_frame_time: time.Time

	image_source: kn.Box
	image_width, image_height, image_channels: i32
	image_data := image.load("image.png", &image_width, &image_height, &image_channels, 4)
	if image_data != nil {
		image_source = kn.copy_image_to_atlas(image_data, int(image_width), int(image_height))
	}

	// Frame loop
	loop: for {
		if limit_fps {
			time.sleep(time.Millisecond * 10)
		}

		frame_time = f32(time.duration_seconds(time.since(last_frame_time)))
		last_frame_time = time.now()

		if animate {
			animation_time += kn.frame_time()
		}

		event: sdl2.Event
		for sdl2.PollEvent(&event) {
			#partial switch event.type {
			case .KEYDOWN:
				#partial switch event.key.keysym.sym {
				case .A:
					animate = !animate
				case .Z:
					limit_fps = !limit_fps
				}
			case .MOUSEMOTION:
				mouse_point = {f32(event.motion.x), f32(event.motion.y)}
			case .QUIT:
				break loop
			case .WINDOWEVENT:
				if event.window.event == .RESIZED {
					window_width, window_height: i32
					sdl2.GetWindowSize(window, &window_width, &window_height)
					platform.surface_config.width = u32(window_width)
					platform.surface_config.height = u32(window_height)
					wgpu.SurfaceConfigure(platform.surface, &platform.surface_config)
					canvas_size = {f32(window_width), f32(window_height)}
				}
			}
		}

		kn.new_frame()

		GRADIENT_COLORS :: [2]kn.Color{kn.Blue, kn.DeepBlue}

		Layout :: struct {
			bounds, box: kn.Box,
		}
		layout := Layout {
			bounds = {100, canvas_size - 100},
			box    = {100, canvas_size - 100},
		}

		COLUMNS :: 3
		ROWS :: 4
		SIZE :: 40

		get_box :: proc(layout: ^Layout) -> kn.Box {
			size := (layout.bounds.hi - layout.bounds.lo) / [2]f32{COLUMNS, ROWS}
			if layout.box.lo.y + size.y > layout.box.hi.y {
				layout.box.lo.x += size.x
				layout.box.lo.y = layout.bounds.lo.y
			}
			result := kn.Box{layout.box.lo, layout.box.lo + size}
			layout.box.lo.y += size.y
			return result
		}

		{
			container := get_box(&layout)
			center := (container.lo + container.hi) / 2
			radius := f32(SIZE)
			box := kn.Box{center - radius, center + radius}

			kn.push_matrix()
			defer kn.pop_matrix()
			kn.translate(center)
			kn.rotate(math.sin(animation_time * 5) * 0.15)
			kn.translate(-center)
			kn.add_box(
				box,
				{10, 30, 30, 10},
				kn.make_linear_gradient(
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

			kn.add_circle(
				center,
				radius,
				kn.make_linear_gradient(
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
			box := kn.Box{center - radius, center + radius}

			kn.push_matrix()
			defer kn.pop_matrix()
			kn.translate(center)
			kn.rotate(math.sin(animation_time * 1.75) * 0.2)
			kn.translate(-center)
			kn.begin_path()
			kn.move_to(box.lo)
			kn.quad_bezier_to({box.lo.x + 30, box.hi.y}, {box.lo.x + 50, box.lo.y + 30})
			kn.quad_bezier_to({box.hi.x, box.hi.y}, {box.hi.x - 20, box.hi.y})
			kn.quad_bezier_to({box.hi.x - 30, box.hi.y - 40}, {box.hi.x - 20, box.lo.y})
			kn.quad_bezier_to({box.lo.x + 20, box.lo.y + 50}, box.lo)
			kn.fill_path(
				kn.make_linear_gradient(
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

			kn.push_matrix()
			defer kn.pop_matrix()
			kn.translate(center)
			kn.rotate(math.sin(animation_time))
			kn.translate(-center)
			kn.begin_path()
			for i := 0; i <= sides; i += 1 {
				a := math.TAU * (f32(i) / f32(sides)) + animation_time * 0.5
				p := center + [2]f32{math.cos(a), math.sin(a)} * radius
				if i == 0 {
					kn.move_to(p)
				} else {
					b :=
						math.TAU * (f32(i) / f32(sides)) -
						(math.TAU / f32(sides * 2)) +
						animation_time * 0.5
					kn.quad_bezier_to(center + [2]f32{math.cos(b), math.sin(b)} * (radius - 20), p)
				}
			}
			container_center := (container.lo + container.hi) / 2
			kn.fill_path(
				kn.make_atlas_sample(
					image_source,
					{container_center - radius, container_center + radius},
					kn.White,
				),
				// kn.make_linear_gradient(
				// 	center - radius,
				// 	center + radius,
				// 	GRADIENT_COLORS[0],
				// 	GRADIENT_COLORS[1],
				// ),
			)
		}

		// Arc
		{
			container := get_box(&layout)
			center := (container.lo + container.hi) / 2
			radius := f32(SIZE)

			t := animation_time * 3
			kn.add_arc(
				center,
				t,
				t + math.TAU * 0.75,
				radius - 4,
				radius,
				paint = kn.make_linear_gradient(
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
			kn.add_cubic_bezier(
				center + {-radius, 0},
				center + {-radius * 0.4, -s},
				center + {radius * 0.4, s},
				center + {radius, 0},
				4.0,
				kn.make_linear_gradient(
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
			kn.add_pie(
				center,
				t,
				-t,
				radius,
				kn.make_linear_gradient(
					center - radius,
					center + radius,
					GRADIENT_COLORS[0],
					GRADIENT_COLORS[1],
				),
			)
		}

		// Icons
		if len(icon_font.glyphs) > 0 {
			container := get_box(&layout)
			center := (container.lo + container.hi) / 2
			radius := f32(SIZE + 5) + math.sin(animation_time * 2) * 10
			size := radius * 2

			kn.push_matrix()
			defer kn.pop_matrix()
			kn.translate(center)
			// kn.rotate(
			// 	math.TAU *
			// 	ease.cubic_in_out(max(math.mod(animation_time, 1.0) - 0.8, 0.0) * 5.0),
			// )
			kn.scale({math.sin(math.mod(animation_time - 0.5, 1) * math.TAU), 1})
			kn.add_glyph(
				icon_font.glyphs[int(animation_time) % len(icon_font.glyphs)],
				size,
				-radius,
				kn.make_linear_gradient(-radius, radius, GRADIENT_COLORS[0], GRADIENT_COLORS[1]),
			)
		}

		{
			container := get_box(&layout)
			center := (container.lo + container.hi) / 2
			size := [2]f32{clamp(1.5 + math.sin(animation_time * 2) * 2, 1, 2), 1} * 90
			box := kn.Box{center - size * 0.5, center + size * 0.5}
			kn.set_paint(kn.DeepBlue)
			kn.add_box_lines(box, 3, 5)
			box.lo += 4
			box.hi -= 4
			kn.set_paint(kn.Blue)
			kn.set_font(font)
			kn.add_string_wrapped(SAMPLE_TEXT, 20, box)
		}

		{
			container := get_box(&layout)
			center := (container.lo + container.hi) / 2
			size := [2]f32{2, 1} * 90
			box := kn.Box{center - size * 0.5, center + size * 0.5}
			kn.set_paint(kn.DeepBlue)
			kn.add_box_lines(box, 3, 5)
			box.lo += 4
			box.hi -= 4
			kn.set_paint(kn.Blue)
			kn.set_font(font)
			kn.add_string_wrapped(
				SAMPLE_TEXT,
				15 * clamp(1.5 + math.sin(animation_time * 2) * 2, 1, 2),
				box,
			)
		}

		{
			container := get_box(&layout)
			center := (container.lo + container.hi) / 2
			kn.set_paint(kn.Blue)
			kn.set_font(font)
			size := kn.add_string(POEM, 12, center, align = {0, 0.5}, justify = 0.5)
		}

		{
			container := get_box(&layout)
			center := (container.lo + container.hi) / 2
			kn.set_paint(kn.Blue)
			kn.set_font(font)
			kn.push_matrix()
			kn.translate(center)
			kn.rotate(math.sin(animation_time * 20) * (0.2 * max(0, math.sin(animation_time * 2))))
			kn.scale({math.sin(math.mod(animation_time - 0.5, 1) * math.TAU), 1})
			kn.add_rune(rune(65 + (int(animation_time) % 26)), 90, 0, 0.5)
			kn.pop_matrix()
		}

		kn.set_font(font)
		kn.add_string(
			fmt.tprintf("FPS: %.0f", kn.get_fps()),
			origin = {},
			size = 16,
			paint = kn.LimeGreen,
		)

		{
			text := "[A] toggle animation\n[Z] toggle fps limit"
			kn.set_font(font)
			kn.add_string(text, 16, {0, canvas_size.y}, align = {0, 1}, paint = kn.White)
		}

		kn.present()

		free_all(context.temp_allocator)
	}
}

