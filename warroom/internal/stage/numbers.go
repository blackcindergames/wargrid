package stage

import (
	"math"
	"strconv"
)

// Contrast and colour distance for a step's `pairs`: the numbers panel of the prototype's stage.js.

type Matrix [9]float64

// Machado 2009, severity 1, on linear RGB (as p2-3a1-states.html #cvd).
var (
	Deuteranopia = &Matrix{0.367322, 0.860646, -0.227968, 0.280085, 0.672501, 0.047413, -0.01182, 0.04294, 0.968881}
	Protanopia   = &Matrix{0.152286, 1.052583, -0.204868, 0.114503, 0.786281, 0.099216, -0.003882, -0.048116, 1.051998}
)

const (
	MinContrast = 3.0  // WCAG, large text and UI parts
	MinDistance = 20.0 // the project's colour-distance bar (map art audit)
)

type rgb [3]float64

func linearChannel(c float64) float64 {
	if c <= 0.04045 {
		return c / 12.92
	}
	return math.Pow((c+0.055)/1.055, 2.4)
}

func linearOf(hex string) rgb {
	var out rgb
	for i := range out {
		v, _ := strconv.ParseUint(hex[1+2*i:3+2*i], 16, 8)
		out[i] = linearChannel(float64(v) / 255)
	}
	return out
}

func simulate(l rgb, m *Matrix) rgb {
	if m == nil {
		return l
	}
	var out rgb
	for r := range out {
		out[r] = math.Min(1, math.Max(0, m[r*3]*l[0]+m[r*3+1]*l[1]+m[r*3+2]*l[2]))
	}
	return out
}

func luminance(l rgb) float64 { return 0.2126*l[0] + 0.7152*l[1] + 0.0722*l[2] }

func labOf(l rgb) [3]float64 {
	f := func(t float64) float64 {
		if t > 216.0/24389 {
			return math.Cbrt(t)
		}
		return ((24389.0/27)*t + 16) / 116
	}
	x := (0.4124*l[0] + 0.3576*l[1] + 0.1805*l[2]) / 0.95047
	y := luminance(l)
	z := (0.0193*l[0] + 0.1192*l[1] + 0.9505*l[2]) / 1.08883
	return [3]float64{116*f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z))}
}

type PairNumbers struct {
	Contrast, Normal, Deut, Prot float64
}

func sq(v float64) float64 { return v * v }

func distance(a, b rgb, m *Matrix) float64 {
	la, lb := labOf(simulate(a, m)), labOf(simulate(b, m))
	return math.Sqrt(sq(la[0]-lb[0]) + sq(la[1]-lb[1]) + sq(la[2]-lb[2]))
}

func NumbersOf(aHex, bHex string) PairNumbers {
	a, b := linearOf(aHex), linearOf(bHex)
	hi, lo := luminance(a), luminance(b)
	if lo > hi {
		hi, lo = lo, hi
	}
	return PairNumbers{(hi + 0.05) / (lo + 0.05), distance(a, b, nil), distance(a, b, Deuteranopia), distance(a, b, Protanopia)}
}
