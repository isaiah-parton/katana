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

import kn ".."
import "../sdl2glue"

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

State :: struct {
	last_second_time:              time.Time,
	average_duration:              f64,
	sum_duration:                  f64,
	frames_this_second:            int,
	limit_fps:                     bool,
	animate:                       bool,
	enable_glyph_gamma_correction: bool,
	animation_time:                f32,
	cursor_position:               [2]f32,
	canvas_size:                   [2]f32,
	frame_seconds:                 f32,
	last_frame_time:               time.Time,
	image_source:                  kn.Box,
	should_close:                  bool,
	font:                          kn.Font,
	icon_font:                     kn.Font,
}

example_gallery :: proc(state: ^State) {
	GRADIENT_COLORS :: [2]kn.Color{kn.BLUE, kn.DEEP_BLUE}

	Layout :: struct {
		bounds, box: kn.Box,
	}
	layout := Layout {
		bounds = {100, state.canvas_size - 100},
		box    = {100, state.canvas_size - 100},
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
		kn.rotate(math.sin(state.animation_time * 5) * 0.15)
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
		kn.rotate(math.sin(state.animation_time * 1.75) * 0.2)
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
		kn.rotate(math.sin(state.animation_time))
		kn.translate(-center)
		kn.begin_path()
		for i := 0; i <= sides; i += 1 {
			a := math.TAU * (f32(i) / f32(sides)) + state.animation_time * 0.5
			p := center + [2]f32{math.cos(a), math.sin(a)} * radius
			if i == 0 {
				kn.move_to(p)
			} else {
				b :=
					math.TAU * (f32(i) / f32(sides)) -
					(math.TAU / f32(sides * 2)) +
					state.animation_time * 0.5
				kn.quad_bezier_to(center + [2]f32{math.cos(b), math.sin(b)} * (radius - 20), p)
			}
		}
		container_center := (container.lo + container.hi) / 2
		kn.fill_path(
			kn.make_atlas_sample(
				state.image_source,
				{container_center - radius, container_center + radius},
				kn.WHITE,
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

		t := state.animation_time * 3
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

		s := math.sin(state.animation_time * 3) * radius * 1.5
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

		t := abs(math.cos(state.animation_time * 8)) * 0.7
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
	if len(state.icon_font.glyphs) > 0 {
		container := get_box(&layout)
		center := (container.lo + container.hi) / 2
		radius := f32(SIZE + 5) + math.sin(state.animation_time * 2) * 10
		size := radius * 2

		kn.push_matrix()
		defer kn.pop_matrix()
		kn.translate(center)
		// kn.rotate(
		// 	math.TAU *
		// 	ease.cubic_in_out(max(math.mod(state.animation_time, 1.0) - 0.8, 0.0) * 5.0),
		// )
		kn.scale({math.sin(math.mod(state.animation_time - 0.5, 1) * math.TAU), 1})
		kn.add_glyph(
			state.icon_font.glyphs[int(state.animation_time) % len(state.icon_font.glyphs)],
			size,
			-radius,
			kn.make_linear_gradient(-radius, radius, GRADIENT_COLORS[0], GRADIENT_COLORS[1]),
		)
	}

	{
		container := get_box(&layout)
		center := (container.lo + container.hi) / 2
		size := [2]f32{clamp(1.5 + math.sin(state.animation_time * 2) * 2, 1, 2), 1} * 90
		box := kn.Box{center - size * 0.5, center + size * 0.5}
		kn.set_paint(kn.DEEP_BLUE)
		kn.add_box_lines(box, 3, 5)
		box.lo += 4
		box.hi -= 4
		kn.set_paint(kn.BLUE)
		kn.set_font(state.font)
		kn.add_string_wrapped(SAMPLE_TEXT, 20, box)
	}

	{
		container := get_box(&layout)
		center := (container.lo + container.hi) / 2
		size := [2]f32{2, 1} * 90
		box := kn.Box{center - size * 0.5, center + size * 0.5}
		kn.set_paint(kn.DEEP_BLUE)
		kn.add_box_lines(box, 3, 5)
		box.lo += 4
		box.hi -= 4
		kn.set_paint(kn.BLUE)
		kn.set_font(state.font)
		kn.add_string_wrapped(
			SAMPLE_TEXT,
			15 * clamp(1.5 + math.sin(state.animation_time * 2) * 2, 1, 2),
			box,
		)
	}

	{
		container := get_box(&layout)
		center := (container.lo + container.hi) / 2
		kn.set_paint(kn.BLUE)
		kn.set_font(state.font)
		size := kn.add_string(POEM, 12, center, align = {0, 0.5}, justify = 0.5)
	}

	{
		container := get_box(&layout)
		center := (container.lo + container.hi) / 2
		kn.set_paint(kn.BLUE)
		kn.set_font(state.font)
		kn.push_matrix()
		kn.translate(center)
		kn.rotate(
			math.sin(state.animation_time * 20) *
			(0.2 * max(0, math.sin(state.animation_time * 2))),
		)
		kn.scale({math.sin(math.mod(state.animation_time - 0.5, 1) * math.TAU), 1})
		kn.add_rune(rune(65 + (int(state.animation_time) % 26)), 90, 0, 0.5)
		kn.pop_matrix()
	}
}

main :: proc() {
	os.set_current_directory(#directory)

	sdl2.Init(sdl2.INIT_VIDEO)
	defer sdl2.Quit()

	window := sdl2.CreateWindow("vgo example", 100, 100, 1200, 800, {.SHOWN, .RESIZABLE})
	defer sdl2.DestroyWindow(window)

	window_width, window_height: i32
	sdl2.GetWindowSize(window, &window_width, &window_height)

	platform := sdl2glue.make_platform_sdl2glue(window)
	defer kn.destroy_platform(&platform)

	kn.start_on_platform(platform)
	defer kn.shutdown()

	state := State {
		limit_fps                     = true,
		animate                       = true,
		enable_glyph_gamma_correction = true,
		canvas_size                   = {f32(window_width), f32(window_height)},
	}

	// Load some fonts
	state.font, _ = kn.load_font_from_files("fonts/Lexend-Medium.png", "fonts/Lexend-Medium.json")
	state.icon_font, _ = kn.load_font_from_files("fonts/icons.png", "fonts/icons.json")

	image_width: i32
	image_height: i32
	image_channels: i32
	image_data := image.load("image.png", &image_width, &image_height, &image_channels, 4)
	if image_data != nil {
		state.image_source = kn.copy_image_to_atlas(
			image_data,
			int(image_width),
			int(image_height),
		)
	}

	// Frame loop
	for !state.should_close {
		if state.limit_fps {
			time.sleep(time.Millisecond * 10)
		}

		state.frame_seconds = f32(time.duration_seconds(time.since(state.last_frame_time)))
		state.last_frame_time = time.now()

		if state.animate {
			state.animation_time += kn.frame_time()
		}

		event: sdl2.Event
		for sdl2.PollEvent(&event) {
			#partial switch event.type {
			case .KEYDOWN:
				#partial switch event.key.keysym.sym {
				case .A:
					state.animate = !state.animate
				case .Z:
					state.limit_fps = !state.limit_fps
				}
			case .MOUSEMOTION:
				state.cursor_position = {f32(event.motion.x), f32(event.motion.y)}
			case .QUIT:
				state.should_close = true
			case .WINDOWEVENT:
				if event.window.event == .RESIZED {
					window_width, window_height: i32
					sdl2.GetWindowSize(window, &window_width, &window_height)
					platform.surface_config.width = u32(window_width)
					platform.surface_config.height = u32(window_height)
					wgpu.SurfaceConfigure(platform.surface, &platform.surface_config)
					state.canvas_size = {f32(window_width), f32(window_height)}
				}
			}
		}

		kn.new_frame()

		example_gallery(&state)
		//

		// center := state.canvas_size / 2
		// box := kn.Box{center - 100, center + 100}
		// kn.push_scissor(kn.make_box(box))
		// kn.add_box_lines(box, 1, paint = kn.RED)
		// kn.push_matrix()
		// kn.translate(center)
		// kn.rotate(math.PI * 0.25)
		// kn.translate(-center)
		// kn.add_box(box, paint = kn.AZURE)
		// kn.pop_matrix()
		// kn.pop_scissor()

		// size := linalg.abs(state.cursor_position - center)
		// box := kn.Box{center - size, center + size}

		// kn.add_box(box, paint = kn.Color{50, 50, 50, 255})
		// t := time.now()
		// text := kn.make_text(POEM, 20, wrap = .Words, max_size = box.hi - box.lo)
		// kn.add_string(fmt.tprintf("%.2f", state.average_duration), 16, {0, 20}, paint = kn.WHITE)
		// state.sum_duration += time.duration_microseconds(time.since(t))
		// state.frames_this_second += 1
		// if time.since(state.last_second_time) >= time.Second {
		// 	state.last_second_time = time.now()
		// 	state.average_duration = state.sum_duration / f64(state.frames_this_second)
		// 	state.sum_duration = 0
		// 	state.frames_this_second = 0
		// }
		// kn.add_text(text, box.lo, paint = kn.LIGHT_GRAY)
		// kn.add_box_lines({box.lo, box.lo + text.size}, 1, paint = kn.RED)
		// for &line in text.lines {
		// 	offset := box.lo + line.offset
		// 	kn.add_box_lines({offset, offset + line.size}, 1, paint = kn.PURPLE)
		// }

		kn.set_font(state.font)
		kn.add_string(
			fmt.tprintf("FPS: %.0f", kn.get_fps()),
			origin = {},
			size = 16,
			paint = kn.LIME_GREEN,
		)


		{
			text := "[A] toggle animation\n[Z] toggle fps limit"
			kn.add_string(text, 16, {0, state.canvas_size.y}, align = {0, 1}, paint = kn.WHITE)
		}

		kn.present()
		fmt.println(kn.core.renderer.timers)

		free_all(context.temp_allocator)
	}
}

