package main

import (
	"math"
)

type SinCosEntry struct {
	Sin float32
	Cos float32
}

// Sine/cosine look-up tables for performance.
// Can be slower than the platforms that support
// hardware trigonometric instructions.
var sincosTable [360]SinCosEntry

func init() {
	for degrees := range 360 {
		sin, cos := math.Sincos(float64(degrees) * math.Pi / 180)
		sincosTable[degrees] = SinCosEntry{
			Sin: float32(sin),
			Cos: float32(cos),
		}
	}
}
