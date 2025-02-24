package vgo

import "core:math"
import "core:math/bits"
import "core:math/linalg"
import "core:strconv"
import "core:strings"

Color :: [4]u8

// Grays
Gray :: proc(shade: f32) -> Color {
	return {u8(shade * 255.0), u8(shade * 255.0), u8(shade * 255.0), 255}
}
Gainsboro :: Color{220, 220, 220, 255}
LightGray :: Color{211, 211, 211, 255}
DarkGray :: Color{169, 169, 169, 255}
DimGray :: Color{105, 105, 105, 255}
LightSlateGray :: Color{119, 136, 153, 255}
SlateGray :: Color{112, 128, 144, 255}
DarkSlateGray :: Color{47, 79, 79, 255}
BlenderGray :: Color{135, 136, 136, 255}
BlenderDarkGray :: Color{58, 58, 58, 255}
BlenderWire :: Color{78, 78, 78, 255}

// CSS 1 Colors
White :: Color{255, 255, 255, 255}
Silver :: Color{192, 192, 192, 255}
Black :: Color{0, 0, 0, 255}
Red :: Color{255, 0, 0, 255}
Maroon :: Color{128, 0, 0, 255}
Lime :: Color{0, 255, 0, 255}
Green :: Color{0, 128, 0, 255}
Blue :: Color{0, 115, 255, 255}
DeepBlue :: Color{0, 0, 255, 255}
Navy :: Color{0, 0, 128, 255}
Yellow :: Color{255, 255, 0, 255}
Orange :: Color{255, 165, 0, 255}
Olive :: Color{128, 128, 0, 255}
Purple :: Color{128, 0, 128, 255}
Fuchsia :: Color{255, 0, 255, 255}
Teal :: Color{0, 128, 128, 255}
Aqua :: Color{0, 255, 255, 255}

// CSS3 colors

// Reds
IndianRed :: Color{205, 92, 92, 255}
LightCoral :: Color{240, 128, 128, 255}
Salmon :: Color{250, 128, 114, 255}
DarkSalmon :: Color{233, 150, 122, 255}
LightSalmon :: Color{255, 160, 122, 255}
Crimson :: Color{220, 20, 60, 255}
FireBrick :: Color{178, 34, 34, 255}
DarkRed :: Color{139, 0, 0, 255}

// Pinks
Pink :: Color{255, 192, 203, 255}
LightPink :: Color{255, 182, 193, 255}
HotPink :: Color{255, 105, 180, 255}
DeepPink :: Color{255, 20, 147, 255}
MediumVioletRed :: Color{199, 21, 133, 255}
PaleVioletRed :: Color{219, 112, 147, 255}

// Oranges
Coral :: Color{255, 127, 80, 255}
Tomato :: Color{255, 99, 71, 255}
OrangeRed :: Color{255, 69, 0, 255}
DarkOrange :: Color{255, 140, 0, 255}

// Yellows
Gold :: Color{255, 215, 0, 255}
LightYellow :: Color{255, 255, 224, 255}
LemonChiffon :: Color{255, 250, 205, 255}
LightGoldenrodYellow :: Color{250, 250, 210, 255}
PapayaWhip :: Color{255, 239, 213, 255}
Moccasin :: Color{255, 228, 181, 255}
PeachPuff :: Color{255, 218, 185, 255}
PaleGoldenrod :: Color{238, 232, 170, 255}
Khaki :: Color{240, 230, 140, 255}
DarkKhaki :: Color{189, 183, 107, 255}

// Purples
Lavender :: Color{230, 230, 250, 255}
Thistle :: Color{216, 191, 216, 255}
Plum :: Color{221, 160, 221, 255}
Violet :: Color{238, 130, 238, 255}
Orchid :: Color{218, 112, 214, 255}
Magenta :: Color{255, 0, 255, 255}
MediumOrchid :: Color{186, 85, 211, 255}
MediumPurple :: Color{147, 112, 219, 255}
BlueViolet :: Color{138, 43, 226, 255}
DarkViolet :: Color{148, 0, 211, 255}
DarkOrchid :: Color{153, 50, 204, 255}
DarkMagenta :: Color{139, 0, 139, 255}
RebeccaPurple :: Color{102, 51, 153, 255}
Indigo :: Color{75, 0, 130, 255}
MediumSlateBlue :: Color{123, 104, 238, 255}
SlateBlue :: Color{106, 90, 205, 255}
DarkSlateBlue :: Color{72, 61, 139, 255}

// Greens
GreenYellow :: Color{173, 255, 47, 255}
Chartreuse :: Color{127, 255, 0, 255}
LawnGreen :: Color{124, 252, 0, 255}
LimeGreen :: Color{50, 205, 50, 255}
PaleGreen :: Color{152, 251, 152, 255}
LightGreen :: Color{144, 238, 144, 255}
MediumSpringGreen :: Color{0, 250, 154, 255}
SpringGreen :: Color{0, 255, 127, 255}
MediumSeaGreen :: Color{60, 179, 113, 255}
SeaGreen :: Color{46, 139, 87, 255}
ForestGreen :: Color{34, 139, 34, 255}
DarkGreen :: Color{0, 100, 0, 255}
YellowGreen :: Color{154, 205, 50, 255}
OliveDrab :: Color{107, 142, 35, 255}
DarkOliveGreen :: Color{85, 107, 47, 255}
MediumAquamarine :: Color{102, 205, 170, 255}
DarkSeaGreen :: Color{143, 188, 143, 255}
LightSeaGreen :: Color{32, 178, 170, 255}
DarkCyan :: Color{0, 139, 139, 255}

// Blues
Cyan :: Color{0, 255, 255, 255}
LightCyan :: Color{224, 255, 255, 255}
PaleTurquoise :: Color{175, 238, 238, 255}
Aquamarine :: Color{127, 255, 212, 255}
Turquoise :: Color{64, 224, 208, 255}
MediumTurquoise :: Color{72, 209, 204, 255}
DarkTurquoise :: Color{0, 206, 209, 255}
CadetBlue :: Color{95, 158, 160, 255}
SteelBlue :: Color{70, 130, 180, 255}
LightSteelBlue :: Color{176, 196, 222, 255}
PowderBlue :: Color{176, 224, 230, 255}
LightBlue :: Color{173, 216, 230, 255}
SkyBlue :: Color{135, 206, 235, 255}
LightSkyBlue :: Color{135, 206, 250, 255}
DeepSkyBlue :: Color{0, 191, 255, 255}
DodgerBlue :: Color{30, 144, 255, 255}
CornflowerBlue :: Color{100, 149, 237, 255}
RoyalBlue :: Color{65, 105, 225, 255}
MediumBlue :: Color{0, 0, 205, 255}
DarkBlue :: Color{0, 0, 139, 255}
MidnightBlue :: Color{25, 25, 112, 255}

// Browns
Cornsilk :: Color{255, 248, 220, 255}
BlanchedAlmond :: Color{255, 235, 205, 255}
Bisque :: Color{255, 228, 196, 255}
NavajoWhite :: Color{255, 222, 173, 255}
Wheat :: Color{245, 222, 179, 255}
BurlyWood :: Color{222, 184, 135, 255}
Tan :: Color{210, 180, 140, 255}
RosyBrown :: Color{188, 143, 143, 255}
SandyBrown :: Color{244, 164, 96, 255}
Goldenrod :: Color{218, 165, 32, 255}
DarkGoldenrod :: Color{184, 134, 11, 255}
Peru :: Color{205, 133, 63, 255}
Chocolate :: Color{210, 105, 30, 255}
SaddleBrown :: Color{139, 69, 19, 255}
Sienna :: Color{160, 82, 45, 255}
Brown :: Color{165, 42, 42, 255}

// Whites
Snow :: Color{255, 250, 250, 255}
Honeydew :: Color{240, 255, 240, 255}
MintCream :: Color{245, 255, 250, 255}
Azure :: Color{240, 255, 255, 255}
AliceBlue :: Color{240, 248, 255, 255}
GhostWhite :: Color{248, 248, 255, 255}
WhiteSmoke :: Color{245, 245, 245, 255}
Seashell :: Color{255, 245, 238, 255}
Beige :: Color{245, 245, 220, 255}
OldLace :: Color{253, 245, 230, 255}
FloralWhite :: Color{255, 250, 240, 255}
Ivory :: Color{255, 255, 240, 255}
AntiqueWhite :: Color{250, 235, 215, 255}
Linen :: Color{250, 240, 230, 255}
LavenderBlush :: Color{255, 240, 245, 255}
MistyRose :: Color{255, 228, 225, 255}

Named_Color :: struct {
	name:  string,
	color: Color,
}

NAMED_COLORS := []Named_Color {
	// Grays
	{"Gray", {128, 128, 128, 255}},
	{"Gainsboro", {220, 220, 220, 255}},
	{"Light Gray", {211, 211, 211, 255}},
	{"Dark Gray", {169, 169, 169, 255}},
	{"Blender Gray", {135, 136, 136, 255}},
	{"Blender Dark Gray", {135, 136, 136, 255}},
	{"Dim Gray", {105, 105, 105, 255}},
	{"Light Slate Gray", {119, 136, 153, 255}},
	{"Slate Gray", {112, 128, 144, 255}},
	{"Dark Slate Gray", {47, 79, 79, 255}},
	// CSS 1 Colors
	{"White", {255, 255, 255, 255}},
	{"Silver", {192, 192, 192, 255}},
	{"BLACK", {0, 0, 0, 255}},
	{"Red", {255, 0, 0, 255}},
	{"Maroon", {128, 0, 0, 255}},
	{"Lime", {0, 255, 0, 255}},
	{"Green", {0, 128, 0, 255}},
	{"Blue", {0, 115, 255, 255}},
	{"DeepBlue", {0, 0, 255, 255}},
	{"Navy", {0, 0, 128, 255}},
	{"Yellow", {255, 255, 0, 255}},
	{"Orange", {255, 165, 0, 255}},
	{"Olive", {128, 128, 0, 255}},
	{"Purple", {128, 0, 128, 255}},
	{"Fuchsia", {255, 0, 255, 255}},
	{"Teal", {0, 128, 128, 255}},
	{"Aqua", {0, 255, 255, 255}},
	// CSS3 colors
	// Reds
	{"IndianRed", {205, 92, 92, 255}},
	{"LightCoral", {240, 128, 128, 255}},
	{"Salmon", {250, 128, 114, 255}},
	{"DarkSalmon", {233, 150, 122, 255}},
	{"LightSalmon", {255, 160, 122, 255}},
	{"Crimson", {220, 20, 60, 255}},
	{"FireBrick", {178, 34, 34, 255}},
	{"DarkRed", {139, 0, 0, 255}},
	// Pinks
	{"Pink", {255, 192, 203, 255}},
	{"LightPink", {255, 182, 193, 255}},
	{"HotPink", {255, 105, 180, 255}},
	{"DeepPink", {255, 20, 147, 255}},
	{"MediumVioletRed", {199, 21, 133, 255}},
	{"PaleVioletRed", {219, 112, 147, 255}},
	// Oranges
	{"Coral", {255, 127, 80, 255}},
	{"Tomato", {255, 99, 71, 255}},
	{"OrangeRed", {255, 69, 0, 255}},
	{"DarkOrange", {255, 140, 0, 255}},
	// Yellows
	{"Gold", {255, 215, 0, 255}},
	{"LightYellow", {255, 255, 224, 255}},
	{"LemonChiffon", {255, 250, 205, 255}},
	{"LightGoldenrodYellow", {250, 250, 210, 255}},
	{"PapayaWhip", {255, 239, 213, 255}},
	{"Moccasin", {255, 228, 181, 255}},
	{"PeachPuff", {255, 218, 185, 255}},
	{"PaleGoldenrod", {238, 232, 170, 255}},
	{"Khaki", {240, 230, 140, 255}},
	{"DarkKhaki", {189, 183, 107, 255}},
	// Purples
	{"Lavender", {230, 230, 250, 255}},
	{"Thistle", {216, 191, 216, 255}},
	{"Plum", {221, 160, 221, 255}},
	{"Violet", {238, 130, 238, 255}},
	{"Orchid", {218, 112, 214, 255}},
	{"Magenta", {255, 0, 255, 255}},
	{"MediumOrchid", {186, 85, 211, 255}},
	{"MediumPurple", {147, 112, 219, 255}},
	{"BlueViolet", {138, 43, 226, 255}},
	{"DarkViolet", {148, 0, 211, 255}},
	{"DarkOrchid", {153, 50, 204, 255}},
	{"DarkMagenta", {139, 0, 139, 255}},
	{"RebeccaPurple", {102, 51, 153, 255}},
	{"Indigo", {75, 0, 130, 255}},
	{"MediumSlateBlue", {123, 104, 238, 255}},
	{"SlateBlue", {106, 90, 205, 255}},
	{"DarkSlateBlue", {72, 61, 139, 255}},
	// Greens
	{"GreenYellow", {173, 255, 47, 255}},
	{"Chartreuse", {127, 255, 0, 255}},
	{"LawnGreen", {124, 252, 0, 255}},
	{"LimeGreen", {50, 205, 50, 255}},
	{"PaleGreen", {152, 251, 152, 255}},
	{"LightGreen", {144, 238, 144, 255}},
	{"MediumSpringGreen", {0, 250, 154, 255}},
	{"SpringGreen", {0, 255, 127, 255}},
	{"MediumSeaGreen", {60, 179, 113, 255}},
	{"SeaGreen", {46, 139, 87, 255}},
	{"ForestGreen", {34, 139, 34, 255}},
	{"DarkGreen", {0, 100, 0, 255}},
	{"YellowGreen", {154, 205, 50, 255}},
	{"OliveDrab", {107, 142, 35, 255}},
	{"DarkOliveGreen", {85, 107, 47, 255}},
	{"MediumAquamarine", {102, 205, 170, 255}},
	{"DarkSeaGreen", {143, 188, 143, 255}},
	{"LightSeaGreen", {32, 178, 170, 255}},
	{"DarkCyan", {0, 139, 139, 255}},
	// Blues
	{"Cyan", {0, 255, 255, 255}},
	{"LightCyan", {224, 255, 255, 255}},
	{"PaleTurquoise", {175, 238, 238, 255}},
	{"Aquamarine", {127, 255, 212, 255}},
	{"Turquoise", {64, 224, 208, 255}},
	{"MediumTurquoise", {72, 209, 204, 255}},
	{"DarkTurquoise", {0, 206, 209, 255}},
	{"CadetBlue", {95, 158, 160, 255}},
	{"SteelBlue", {70, 130, 180, 255}},
	{"LightSteelBlue", {176, 196, 222, 255}},
	{"PowderBlue", {176, 224, 230, 255}},
	{"LightBlue", {173, 216, 230, 255}},
	{"SkyBlue", {135, 206, 235, 255}},
	{"LightSkyBlue", {135, 206, 250, 255}},
	{"DeepSkyBlue", {0, 191, 255, 255}},
	{"DodgerBlue", {30, 144, 255, 255}},
	{"CornflowerBlue", {100, 149, 237, 255}},
	{"RoyalBlue", {65, 105, 225, 255}},
	{"MediumBlue", {0, 0, 205, 255}},
	{"DarkBlue", {0, 0, 139, 255}},
	{"MidnightBlue", {25, 25, 112, 255}},
	// Browns
	{"Cornsilk", {255, 248, 220, 255}},
	{"BlanchedAlmond", {255, 235, 205, 255}},
	{"Bisque", {255, 228, 196, 255}},
	{"NavajoWhite", {255, 222, 173, 255}},
	{"Wheat", {245, 222, 179, 255}},
	{"BurlyWood", {222, 184, 135, 255}},
	{"Tan", {210, 180, 140, 255}},
	{"RosyBrown", {188, 143, 143, 255}},
	{"SandyBrown", {244, 164, 96, 255}},
	{"Goldenrod", {218, 165, 32, 255}},
	{"DarkGoldenrod", {184, 134, 11, 255}},
	{"Peru", {205, 133, 63, 255}},
	{"Chocolate", {210, 105, 30, 255}},
	{"SaddleBrown", {139, 69, 19, 255}},
	{"Sienna", {160, 82, 45, 255}},
	{"Brown", {165, 42, 42, 255}},
	// Whites
	{"Snow", {255, 250, 250, 255}},
	{"Honeydew", {240, 255, 240, 255}},
	{"Mint Cream", {245, 255, 250, 255}},
	{"Azure", {240, 255, 255, 255}},
	{"Alice Blue", {240, 248, 255, 255}},
	{"Ghost White", {248, 248, 255, 255}},
	{"White Smoke", {245, 245, 245, 255}},
	{"Seashell", {255, 245, 238, 255}},
	{"Beige", {245, 245, 220, 255}},
	{"Old Lace", {253, 245, 230, 255}},
	{"Floral White", {255, 250, 240, 255}},
	{"Ivory", {255, 255, 240, 255}},
	{"Antique White", {250, 235, 215, 255}},
	{"Linen", {250, 240, 230, 255}},
	{"Lavender Blush", {255, 240, 245, 255}},
	{"Misty Rose", {255, 228, 225, 255}},
}

color_distance :: proc(c1, c2: Color) -> f32 {
	dr := f32(c1.r) - f32(c2.r)
	dg := f32(c1.g) - f32(c2.g)
	db := f32(c1.b) - f32(c2.b)
	return math.sqrt_f32(dr * dr + dg * dg + db * db)
}

find_nearest_color :: proc(target: Color) -> Named_Color {
	min_distance := f32(math.F32_MAX)
	nearest_color := NAMED_COLORS[0]

	for color in NAMED_COLORS {
		dist := color_distance(target, color.color)
		if dist < min_distance {
			min_distance = dist
			nearest_color = color
		}
	}

	return nearest_color
}

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

color_from_hex :: proc(hex: u32) -> Color {
	return transmute(Color)bits.reverse_bits(hex << 8)
}

hex_from_color :: proc(color: Color) -> u32 {
	return bits.reverse_bits(transmute(u32)color) >> 8
}

hsva_from_color :: proc(color: Color) -> (hsva: [4]f32) {
	rgba: [4]f32 = {f32(color.r), f32(color.g), f32(color.b), f32(color.a)} / 255

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

color_from_hsva :: proc(hsva: [4]f32) -> Color {
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

	return {u8(r * 255.0), u8(g * 255.0), u8(b * 255.0), u8(hsva.w * 255.0)}
}

hsl_from_norm_rgb :: proc(rgb: [3]f32) -> [3]f32 {
	v := max(rgb.r, rgb.g, rgb.b)
	c := v - min(rgb.r, rgb.g, rgb.b)
	f := 1 - abs(v + v - c - 1)
	h :=
		((rgb.g - rgb.b) / c) if (c > 0 && v == rgb.r) else ((2 + (rgb.b - rgb.r) / c) if v == rgb.g else (4 + (rgb.r - rgb.g) / c))
	return {60 * ((h + 6) if h < 0 else h), (c / f) if f > 0 else 0, (v + v - c) / 2}
}

color_from :: proc {
	color_from_hex,
	color_from_hsl,
	color_from_hsva,
}

hsl_from :: proc {
	hsl_from_norm_rgb,
	hsl_from_color,
}

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

hsl_from_color :: proc(color: Color) -> [4]f32 {
	hsva := linalg.vector4_rgb_to_hsl(
		linalg.Vector4f32 {
			f32(color.r) / 255.0,
			f32(color.g) / 255.0,
			f32(color.b) / 255.0,
			f32(color.a) / 255.0,
		},
	)
	return hsva.xyzw
}

color_from_hsl :: proc(hue, saturation, value: f32) -> Color {
	rgba := linalg.vector4_hsl_to_rgb(hue, saturation, value, 1.0)
	return {u8(rgba.r * 255.0), u8(rgba.g * 255.0), u8(rgba.b * 255.0), u8(rgba.a * 255.0)}
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
