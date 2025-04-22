package sdl2glue

import kn ".."
import "vendor:sdl2"
import "vendor:wgpu"
import "vendor:wgpu/sdl2glue"

make_platform_sdl2glue :: proc(window: ^sdl2.Window) -> (platform: Platform) {
	platform.instance = wgpu.CreateInstance() // &{
	// 	nextInChain = &wgpu.InstanceExtras {
	// 		sType = .InstanceExtras,
	// 		backends = {.GL},
	// 	},
	// },

	if platform.instance == nil {
		panic("Failed to create instance!")
	}

	platform.surface = sdl2glue.GetSurface(platform.instance, window)
	if platform.surface == nil {
		panic("Failed to create surface!")
	}

	platform_get_adapter_and_device(&platform)

	platform.surface_config, _ = surface_configuration(
		platform.device,
		platform.adapter,
		platform.surface,
	)
	core.renderer.surface_config = platform.surface_config

	width, height: i32
	sdl2.GetWindowSize(window, &width, &height)
	platform.surface_config.width = u32(width)
	platform.surface_config.height = u32(height)

	wgpu.SurfaceConfigure(platform.surface, &platform.surface_config)

	return
}
