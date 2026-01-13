package katana

import "core:fmt"
import "core:image"

Image :: struct {
	atlas_resource: Atlas_Resource,
}

load_image_from_file :: proc(path: string) -> (result: Image, ok: bool) {
	if img, err := image.load_from_file(path, {.alpha_add_if_missing}); err == nil {
		result.atlas_resource = Atlas_Resource {
			pixels = raw_data(img.pixels.buf),
			width  = img.width,
			height = img.height,
		}
		ok = true
	} else {
		fmt.eprintln(err)
	}
	return
}

load_image_from_data :: proc(data: []u8) -> (result: Image, ok: bool) {
	return
}

load_image :: proc {
	load_image_from_file,
	load_image_from_data,
}

