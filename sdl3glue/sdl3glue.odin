package sdl3glue

import kn ".."
import "vendor:sdl3"
import "vendor:wgpu"
import "vendor:wgpu/sdl3glue"

make_platform_sdl3glue :: proc(window: ^sdl3.Window) -> (platform: kn.Platform) {
	platform.instance = wgpu.CreateInstance() // &{
	// 	nextInChain = &wgpu.InstanceExtras {
	// 		sType = .InstanceExtras,
	// 		backends = {.GL},
	// 	},
	// },

	if platform.instance == nil {
		panic("Failed to create instance!")
	}

	platform.surface = sdl3glue.GetSurface(platform.instance, window)
	if platform.surface == nil {
		panic("Failed to create surface!")
	}

	kn.platform_get_adapter_and_device(&platform)

	platform.surface_config, _ = kn.surface_configuration(
		platform.device,
		platform.adapter,
		platform.surface,
	)

	width, height: i32
	sdl3.GetWindowSize(window, &width, &height)
	platform.surface_config.width = u32(width)
	platform.surface_config.height = u32(height)

	kn.core.renderer.surface_config = platform.surface_config

	wgpu.SurfaceConfigure(platform.surface, &platform.surface_config)

	return
}

