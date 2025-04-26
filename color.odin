package katana

import "core:math"
import "core:math/bits"
import "core:math/linalg"
import "core:strconv"
import "core:strings"

Color :: [4]u8

// Grays
GRAY :: proc(shade: f32) -> Color {
	return {u8(shade * 255.0), u8(shade * 255.0), u8(shade * 255.0), 255}
}
GAINSBORO :: Color{220, 220, 220, 255}
LIGHT_GRAY :: Color{211, 211, 211, 255}
DARK_GRAY :: Color{169, 169, 169, 255}
DIM_GRAY :: Color{105, 105, 105, 255}
LIGHT_SLATE_GRAY :: Color{119, 136, 153, 255}
SLATE_GRAY :: Color{112, 128, 144, 255}
DARK_SLATE_GRAY :: Color{47, 79, 79, 255}
BLENDER_GRAY :: Color{135, 136, 136, 255}
BLENDER_DARK_GRAY :: Color{58, 58, 58, 255}
BLENDER_WIRE :: Color{78, 78, 78, 255}

WHITE :: Color{255, 255, 255, 255}
SILVER :: Color{192, 192, 192, 255}
BLACK :: Color{0, 0, 0, 255}
RED :: Color{255, 0, 0, 255}
MAROON :: Color{128, 0, 0, 255}
LIME :: Color{0, 255, 0, 255}
GREEN :: Color{0, 128, 0, 255}
BLUE :: Color{0, 115, 255, 255}
DEEP_BLUE :: Color{0, 0, 255, 255}
NAVY :: Color{0, 0, 128, 255}
YELLOW :: Color{255, 255, 0, 255}
ORANGE :: Color{255, 165, 0, 255}
OLIVE :: Color{128, 128, 0, 255}
PURPLE :: Color{128, 0, 128, 255}
FUCHSIA :: Color{255, 0, 255, 255}
TEAL :: Color{0, 128, 128, 255}
AQUA :: Color{0, 255, 255, 255}

INDIAN_RED :: Color{205, 92, 92, 255}
LIGHT_CORAL :: Color{240, 128, 128, 255}
SALMON :: Color{250, 128, 114, 255}
DARK_SALMON :: Color{233, 150, 122, 255}
LIGHT_SALMON :: Color{255, 160, 122, 255}
CRIMSON :: Color{220, 20, 60, 255}
FIRE_BRICK :: Color{178, 34, 34, 255}
DARK_RED :: Color{139, 0, 0, 255}

PINK :: Color{255, 192, 203, 255}
LIGHT_PINK :: Color{255, 182, 193, 255}
HOT_PINK :: Color{255, 105, 180, 255}
DEEP_PINK :: Color{255, 20, 147, 255}
MEDIUM_VIOLET_RED :: Color{199, 21, 133, 255}
PALE_VIOLET_RED :: Color{219, 112, 147, 255}

CORAL :: Color{255, 127, 80, 255}
TOMATO :: Color{255, 99, 71, 255}
ORANGE_RED :: Color{255, 69, 0, 255}
DARK_ORANGE :: Color{255, 140, 0, 255}

GOLD :: Color{255, 215, 0, 255}
LIGHT_YELLOW :: Color{255, 255, 224, 255}
LEMON_CHIFFON :: Color{255, 250, 205, 255}
LIGHT_GOLDENROD_YELLOW :: Color{250, 250, 210, 255}
PAPAYA_WHIP :: Color{255, 239, 213, 255}
MOCCASIN :: Color{255, 228, 181, 255}
PEACH_PUFF :: Color{255, 218, 185, 255}
PALE_GOLDENROD :: Color{238, 232, 170, 255}
KHAKI :: Color{240, 230, 140, 255}
DARK_KHAKI :: Color{189, 183, 107, 255}

LAVENDER :: Color{230, 230, 250, 255}
THISTLE :: Color{216, 191, 216, 255}
PLUM :: Color{221, 160, 221, 255}
VIOLET :: Color{238, 130, 238, 255}
ORCHID :: Color{218, 112, 214, 255}
MAGENTA :: Color{255, 0, 255, 255}
MEDIUM_ORCHID :: Color{186, 85, 211, 255}
MEDIUM_PURPLE :: Color{147, 112, 219, 255}
BLUE_VIOLET :: Color{138, 43, 226, 255}
DARK_VIOLET :: Color{148, 0, 211, 255}
DARK_ORCHID :: Color{153, 50, 204, 255}
DARK_MAGENTA :: Color{139, 0, 139, 255}
REBECCA_PURPLE :: Color{102, 51, 153, 255}
INDIGO :: Color{75, 0, 130, 255}
MEDIUM_SLATE_BLUE :: Color{123, 104, 238, 255}
SLATE_BLUE :: Color{106, 90, 205, 255}
DARK_SLATE_BLUE :: Color{72, 61, 139, 255}

GREEN_YELLOW :: Color{173, 255, 47, 255}
CHARTREUSE :: Color{127, 255, 0, 255}
LAWN_GREEN :: Color{124, 252, 0, 255}
LIME_GREEN :: Color{50, 205, 50, 255}
PALE_GREEN :: Color{152, 251, 152, 255}
LIGHT_GREEN :: Color{144, 238, 144, 255}
MEDIUM_SPRING_GREEN :: Color{0, 250, 154, 255}
SPRING_GREEN :: Color{0, 255, 127, 255}
MEDIUM_SEA_GREEN :: Color{60, 179, 113, 255}
SEA_GREEN :: Color{46, 139, 87, 255}
FOREST_GREEN :: Color{34, 139, 34, 255}
DARK_GREEN :: Color{0, 100, 0, 255}
YELLOW_GREEN :: Color{154, 205, 50, 255}
OLIVE_DRAB :: Color{107, 142, 35, 255}
DARK_OLIVE_GREEN :: Color{85, 107, 47, 255}
MEDIUM_AQUAMARINE :: Color{102, 205, 170, 255}
DARK_SEA_GREEN :: Color{143, 188, 143, 255}
LIGHT_SEA_GREEN :: Color{32, 178, 170, 255}
DARK_CYAN :: Color{0, 139, 139, 255}

CYAN :: Color{0, 255, 255, 255}
LIGHT_CYAN :: Color{224, 255, 255, 255}
PALE_TURQUOISE :: Color{175, 238, 238, 255}
AQUAMARINE :: Color{127, 255, 212, 255}
TURQUOISE :: Color{64, 224, 208, 255}
MEDIUM_TURQUOISE :: Color{72, 209, 204, 255}
DARK_TURQUOISE :: Color{0, 206, 209, 255}
CADET_BLUE :: Color{95, 158, 160, 255}
STEEL_BLUE :: Color{70, 130, 180, 255}
LIGHT_STEEL_BLUE :: Color{176, 196, 222, 255}
POWDER_BLUE :: Color{176, 224, 230, 255}
LIGHT_BLUE :: Color{173, 216, 230, 255}
SKY_BLUE :: Color{135, 206, 235, 255}
LIGHT_SKY_BLUE :: Color{135, 206, 250, 255}
DEEP_SKY_BLUE :: Color{0, 191, 255, 255}
DODGER_BLUE :: Color{30, 144, 255, 255}
CORNFLOWER_BLUE :: Color{100, 149, 237, 255}
ROYAL_BLUE :: Color{65, 105, 225, 255}
MEDIUM_BLUE :: Color{0, 0, 205, 255}
DARK_BLUE :: Color{0, 0, 139, 255}
MIDNIGHT_BLUE :: Color{25, 25, 112, 255}

CORNSILK :: Color{255, 248, 220, 255}
BLANCHED_ALMOND :: Color{255, 235, 205, 255}
BISQUE :: Color{255, 228, 196, 255}
NAVAJO_WHITE :: Color{255, 222, 173, 255}
WHEAT :: Color{245, 222, 179, 255}
BURLY_WOOD :: Color{222, 184, 135, 255}
TAN :: Color{210, 180, 140, 255}
ROSY_BROWN :: Color{188, 143, 143, 255}
SANDY_BROWN :: Color{244, 164, 96, 255}
GOLDENROD :: Color{218, 165, 32, 255}
DARK_GOLDENROD :: Color{184, 134, 11, 255}
PERU :: Color{205, 133, 63, 255}
CHOCOLATE :: Color{210, 105, 30, 255}
SADDLE_BROWN :: Color{139, 69, 19, 255}
SIENNA :: Color{160, 82, 45, 255}
BROWN :: Color{165, 42, 42, 255}

SNOW :: Color{255, 250, 250, 255}
HONEYDEW :: Color{240, 255, 240, 255}
MINT_CREAM :: Color{245, 255, 250, 255}
AZURE :: Color{240, 255, 255, 255}
ALICE_BLUE :: Color{240, 248, 255, 255}
GHOST_WHITE :: Color{248, 248, 255, 255}
WHITE_SMOKE :: Color{245, 245, 245, 255}
SEASHELL :: Color{255, 245, 238, 255}
BEIGE :: Color{245, 245, 220, 255}
OLD_LACE :: Color{253, 245, 230, 255}
FLORAL_WHITE :: Color{255, 250, 240, 255}
IVORY :: Color{255, 255, 240, 255}
ANTIQUE_WHITE :: Color{250, 235, 215, 255}
LINEN :: Color{250, 240, 230, 255}
LAVENDER_BLUSH :: Color{255, 240, 245, 255}
MISTY_ROSE :: Color{255, 228, 225, 255}

parse_rgba :: proc(str: string) -> (res: Color, ok: bool) {
	strs := strings.split(str, ", ")
	defer delete(strs)
	if len(strs) == 0 || len(strs) > 4 {
		return
	}
	for s, i in strs {
		num := strconv.parse_u64(s) or_return
		res[i] = u8(min(num, 255))
	}
	ok = true
	return
}

parse_hex :: proc(hex_str: string) -> (out: Color) {
	s := hex_str
	if strings.has_prefix(s, "#") {
		s = s[1:]
	}
	out = 255
	switch len(s) {
	case 6:
		for i in 0 ..< 3 {
			byte, byte_ok := strconv.parse_u64_of_base(s[i * 2:i * 2 + 2], 16)
			if !byte_ok {
				return
			}
			out[i] = u8(byte)
		}
	}
	return
}

hex_from_color :: proc(color: Color) -> u32 {
	return bits.reverse_bits(transmute(u32)color) >> 8
}

hsva_from_rgba :: proc(rgba: [4]f32) -> (hsva: [4]f32) {
	low := min(rgba.r, rgba.g, rgba.b)
	high := max(rgba.r, rgba.g, rgba.b)
	hsva.w = rgba.a

	hsva.z = high
	delta := high - low

	if delta < 0.00001 {
		return
	}

	if high > 0 {
		hsva.y = delta / high
	} else {
		return
	}

	if rgba.r >= high {
		hsva.x = (rgba.g - rgba.b) / delta
	} else {
		if rgba.g >= high {
			hsva.x = 2.0 + (rgba.b - rgba.r) / delta
		} else {
			hsva.x = 4.0 + (rgba.r - rgba.g) / delta
		}
	}

	hsva.x *= 60

	if hsva.x < 0 {
		hsva.x += 360
	}

	return
}

rgba_from_hsva :: proc(hsva: [4]f32) -> [4]f32 {
	r, g, b, k, t: f32

	k = math.mod(5.0 + hsva.x / 60.0, 6)
	t = 4.0 - k
	k = clamp(min(t, k), 0, 1)
	r = hsva.z - hsva.z * hsva.y * k

	k = math.mod(3.0 + hsva.x / 60.0, 6)
	t = 4.0 - k
	k = clamp(min(t, k), 0, 1)
	g = hsva.z - hsva.z * hsva.y * k

	k = math.mod(1.0 + hsva.x / 60.0, 6)
	t = 4.0 - k
	k = clamp(min(t, k), 0, 1)
	b = hsva.z - hsva.z * hsva.y * k

	return {r, g, b, hsva.w}
}

// hsva_from_rgba :: proc(rgba: [4]f32) -> [4]f32 {
// 	v := max(rgba.r, rgba.g, rgba.b)
// 	c := v - min(rgba.r, rgba.g, rgba.b)
// 	f := 1 - abs(v + v - c - 1)
// 	h :=
// 		((rgba.g - rgba.b) / c) if (c > 0 && v == rgba.r) else ((2 + (rgba.b - rgba.r) / c) if v == rgba.g else (4 + (rgba.r - rgba.g) / c))
// 	return {60 * ((h + 6) if h < 0 else h), (c / f) if f > 0 else 0, (v + v - c) / 2, rgba.a}
// }

mix :: proc(time: f32, colors: ..Color) -> Color {
	if len(colors) > 0 {
		if len(colors) == 1 {
			return colors[0]
		}
		if time <= 0 {
			return colors[0]
		} else if time >= f32(len(colors) - 1) {
			return colors[len(colors) - 1]
		} else {
			i := int(math.floor(time))
			t := time - f32(i)
			return(
				colors[i] +
				{
						u8((f32(colors[i + 1].r) - f32(colors[i].r)) * t),
						u8((f32(colors[i + 1].g) - f32(colors[i].g)) * t),
						u8((f32(colors[i + 1].b) - f32(colors[i].b)) * t),
						u8((f32(colors[i + 1].a) - f32(colors[i].a)) * t),
					} \
			)
		}
	}
	return {}
}

luminance_of :: proc(color: Color) -> f32 {
	return(
		(f32(color.r) / 255.0) * 0.299 +
		(f32(color.g) / 255.0) * 0.587 +
		(f32(color.b) / 255.0) * 0.114 \
	)
}

color_from_hsla :: proc(h: f32, s: f32, l: f32, a: f32 = 1.0) -> [4]f32 {
	return color_from_hsla_array({h, s, l, a})
}

color_from_hsla_array :: proc(hsla: [4]f32) -> [4]f32 {
	return linalg.vector4_hsl_to_rgb(hsla.x, hsla.y, hsla.z, hsla.w)
}

rgba_from_color :: proc(color: Color) -> [4]f32 {
	return {f32(color.r) / 255.0, f32(color.g) / 255.0, f32(color.b) / 255.0, f32(color.a) / 255.0}
}

hsla_from_rgba :: proc(rgba: [4]f32) -> [4]f32 {
	return linalg.vector4_rgb_to_hsl(rgba)
}

fade :: proc(color: Color, alpha: f32) -> Color {
	return {color.r, color.g, color.b, u8(f32(color.a) * alpha)}
}

blend_colors_tint :: proc(dst, src, tint: Color) -> (out: Color) {
	out = 255

	src := src
	src.r = u8((u32(src.r) * (u32(tint.r) + 1)) >> 8)
	src.g = u8((u32(src.g) * (u32(tint.g) + 1)) >> 8)
	src.b = u8((u32(src.b) * (u32(tint.b) + 1)) >> 8)
	src.a = u8((u32(src.a) * (u32(tint.a) + 1)) >> 8)

	if (src.a == 0) {
		out = dst
	} else if src.a == 255 {
		out = src
	} else {
		alpha := u32(src.a) + 1
		out.a = u8((u32(alpha) * 256 + u32(dst.a) * (256 - alpha)) >> 8)

		if out.a > 0 {
			out.r = u8(
				((u32(src.r) * alpha * 256 + u32(dst.r) * u32(dst.a) * (256 - alpha)) /
					u32(out.a)) >>
				8,
			)
			out.g = u8(
				((u32(src.g) * alpha * 256 + u32(dst.g) * u32(dst.a) * (256 - alpha)) /
					u32(out.a)) >>
				8,
			)
			out.b = u8(
				((u32(src.b) * alpha * 256 + u32(dst.b) * u32(dst.a) * (256 - alpha)) /
					u32(out.a)) >>
				8,
			)
		}
	}
	return
}

blend_colors_time :: proc(dst, src: Color, time: f32) -> (out: Color) {
	return blend_colors_tint(dst, src, fade(255, time))
}

blend :: proc {
	blend_colors_time,
	blend_colors_tint,
}

