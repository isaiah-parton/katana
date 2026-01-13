package katana

import "core:fmt"
import "vendor:wgpu"

Atlas_Key :: u32

Atlas_Resource :: struct {
	width:  int,
	height: int,
	pixels: rawptr,
	source: Box,
	key:    Atlas_Key,
}

Atlas :: struct {
	key:            Atlas_Key,
	texture:        wgpu.Texture,
	size:           f32,
	offset:         [2]f32,
	content_height: f32,
}

atlas_init :: proc(self: ^Atlas) {
	self.size = f32(min(core.renderer.device_limits.maxTextureDimension2D, 8196))
	self.texture = wgpu.DeviceCreateTexture(
		core.renderer.device,
		&{
			usage = {.CopySrc, .CopyDst, .TextureBinding},
			dimension = ._2D,
			size = {u32(self.size), u32(self.size), 1},
			format = .RGBA8Unorm,
			mipLevelCount = 1,
			sampleCount = 1,
		},
	)
	self.key = 1
}

atlas_uninit :: proc(self: ^Atlas) {
	wgpu.TextureDestroy(self.texture)
	self^ = {}
}

atlas_add :: proc(self: ^Atlas, resource: ^Atlas_Resource) {
	assert(resource != nil)
	size := [2]f32{f32(resource.width), f32(resource.height)}
	if self.offset.x + size.x > self.size {
		self.offset.x = 0
		self.offset.y += self.content_height + 1
		self.content_height = 0
	}
	if self.offset.y + size.y > self.size {
		atlas_clear(self)
	}

	box := Box{self.offset, self.offset + size}

	// Write texture data
	wgpu.QueueWriteTexture(
		core.renderer.queue,
		&{texture = self.texture, origin = {x = u32(box.lo.x), y = u32(box.lo.y)}},
		resource.pixels,
		uint(resource.width * resource.height * 4),
		&{bytesPerRow = u32(box.hi.x - box.lo.x) * 4, rowsPerImage = u32(box.hi.y - box.lo.y)},
		&{
			width = u32(box.hi.x - box.lo.x),
			height = u32(box.hi.y - box.lo.y),
			depthOrArrayLayers = 1,
		},
	)

	resource.key = self.key
	resource.source = {box.lo, box.hi}

	self.offset.x += size.x + 1
	self.content_height = max(self.content_height, size.y)
}

atlas_clear :: proc(self: ^Atlas) {
	self.key += 1
	self.offset = {}
	self.content_height = 0
}

atlas_get :: proc(self: ^Atlas, resource: ^Atlas_Resource) -> Box {
	if resource.key != self.key {
		atlas_add(self, resource)
	}
	return resource.source
}

