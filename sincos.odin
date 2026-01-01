package main

import "core:math"

Sine_Cosine_Table_Entry :: struct {
	sin: f32,
	cos: f32,
}

// Sine/cosine look-up tables for performance.
// Can be slower than the platforms that support
// hardware trigonometric instructions.
sincos_table: [360]Sine_Cosine_Table_Entry

fill_sincos_table :: proc() {
	for degrees in 0 ..< 360 {
		sin, cos := math.sincos(math.to_radians(f32(degrees)))
		sincos_table[degrees].sin = sin
		sincos_table[degrees].cos = cos
	}
}
