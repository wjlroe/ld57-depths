package main

import "base:runtime"
import "core:bytes"
import "core:fmt"
import "core:image"
import "core:image/tga"
import "core:log"
import "core:math"
import "core:mem"
import "core:reflect"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

float_to_int_color :: proc(color: v4) -> v4s {
	return v4s{
		int(math.round(color.r * 255.0)),
		int(math.round(color.g * 255.0)),
		int(math.round(color.b * 255.0)),
		int(math.round(color.a * 255.0)),
	}
}

hex_to_int :: proc(hex: string) -> (n: u8, ok: bool) {
	number : u64
	number, ok = strconv.parse_u64_of_base(hex, 16)
	if number < 256 {
		n = u8(number)
		ok = true
		return
	}
	return
}

hex_to_float :: proc(hex: string) -> f32 {
	n, ok := strconv.parse_u64_of_base(hex, 16)
	if ok {
		return f32(n)
	}
	return 0.0
}

color_from_hex :: proc(hex: string) -> rl.Color {
	r, g, b : u8
	ok : bool
	r, ok = hex_to_int(hex[1:3])
	assert(ok)
	g, ok = hex_to_int(hex[3:5])
	assert(ok)
	b, ok = hex_to_int(hex[5:7])
	assert(ok)
	return {r, g, b, 255}
}

rgb_to_hsl :: proc(rgb: v3) -> v3 {
	min_color := min(rgb.r, rgb.g, rgb.b)
	max_color := max(rgb.r, rgb.g, rgb.b)
	luminance := (min_color + max_color) / 2.0
	saturation : f32
	if min_color == max_color {
		saturation = 0.0
	} else {
		if luminance <= 0.5 {
			saturation = (max_color - min_color) / (max_color + min_color)
		} else {
			saturation = (max_color - min_color) / (2.0 - max_color - min_color)
		}
	}
	hue : f32
	if rgb.r == rgb.g && rgb.g == rgb.b {
		hue = 0.0
	} else if rgb.r == max_color {
		hue = (rgb.g - rgb.b) / (max_color - min_color)
	} else if rgb.g == max_color {
		hue = 2.0 + (rgb.b - rgb.r) / (max_color - min_color)
	} else if rgb.b == max_color {
		hue = 4.0 + (rgb.r - rgb.g) / (max_color - min_color)
	}
	hue *= 60.0
	if hue < 0.0 {
		hue += 360.0
	}
	hue /= 360.0
	return v3{hue, saturation, luminance}
}

hsl_to_rgb :: proc(hsl: v3) -> (rgb: v4) {
	hue := hsl.x
	saturation := hsl.y
	luminance := hsl.z
	if saturation == 0.0 {
		rgb.r = luminance
		rgb.g = luminance
		rgb.b = luminance
		return
	} else {
		c := (1.0 - abs(2.0 * luminance - 1.0)) * saturation
		h := hue * 360.0
		x := c * (1.0 - abs(math.mod(h / 60.0, 2.0) - 1.0))
		m := luminance - c / 2.0
		if h < 60.0 {
			rgb.r = m + c
			rgb.g = m + x
			rgb.b = m + 0.0
			return
		} else if h < 120.0 {
			rgb.r = m + x
			rgb.g = m + c
			rgb.b = m + 0.0
			return
		} else if h < 180.0 {
			rgb.r = m + 0.0
			rgb.g = m + c
			rgb.b = m + x
			return
		} else if h < 240.0 {
			rgb.r = m + 0.0
			rgb.g = m + x
			rgb.b = m + c
		} else if h < 300.0 {
			rgb.r = m + x
			rgb.g = m + 0.0
			rgb.b = m + c
			return
		} else {
			rgb.r = m + c
			rgb.g = m + 0.0
			rgb.b = m + x
			return
		}
	}
	return
}

lighten_color :: proc(color: v4, percent: f32) -> v4 {
	new_color_hsl := rgb_to_hsl(v3(color.rgb))
	new_color_hsl.z = min(1.0, new_color_hsl.z + percent)
	new_color := hsl_to_rgb(new_color_hsl)
	new_color.a = color.a
	return new_color
}

darken_color :: proc(color: v4, percent: f32) -> v4 {
	new_color_hsl := rgb_to_hsl(v3(color.rgb))
	new_color_hsl.z = max(0.0, new_color_hsl.z - percent)
	new_color := hsl_to_rgb(new_color_hsl)
	new_color.a = color.a
	return new_color
}

crude_invert_color :: proc(color: v4) -> v4 {
	int_color := float_to_int_color(color)
	int_color.r = 255 - int_color.r
	int_color.g = 255 - int_color.g
	int_color.b = 255 - int_color.b
	return v4{
		f32(int_color.r) / 255.0,
		f32(int_color.g) / 255.0,
		f32(int_color.b) / 255.0,
		color.a,
	}
}

color_transparent := v4{0.0, 0.0, 0.0, 0.0}
color_red := color_from_hex("#ff0000")
color_green := color_from_hex("#00ff00")
color_blue := color_from_hex("#0000ff")
color_black := color_from_hex("#000000")
color_grey := color_from_hex("#ededed")
color_pink := color_from_hex("#ec39c6")
color_navy := color_from_hex("#3636cc")
color_gold := color_from_hex("#ffd700")
color_yellow := color_from_hex("#ffff00")

Color_Format :: enum{RED, RGB, RGBA}
