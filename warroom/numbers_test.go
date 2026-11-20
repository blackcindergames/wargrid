package main

import (
	"math"
	"testing"
)

// Reference values come from running the prototype's stage.js pairNumbers on the same colours.
func TestNumbersMatchThePrototype(t *testing.T) {
	cases := []struct {
		a, b                         string
		contrast, normal, deut, prot float64
	}{
		{"#f0776a", "#d6120c", 1.9113618677901558, 39.85184321729743, 28.332483678489226, 31.859422278475304},
		{"#ffffff", "#000000", 21, 100.00000068001582, 99.99997303280854, 100.00000068001582},
		{"#60e5ed", "#0a0f14", 12.76230009475029, 87.57575182332934, 79.40283789577076, 83.59202510007847},
		{"#b2a568", "#3f8f4f", 1.6132796873798765, 38.21903694367416, 18.658335628012704, 11.671466566529272},
	}
	for _, c := range cases {
		got := numbersOf(c.a, c.b)
		for name, pair := range map[string][2]float64{"contrast": {got.Contrast, c.contrast}, "normal": {got.Normal, c.normal}, "deut": {got.Deut, c.deut}, "prot": {got.Prot, c.prot}} {
			if math.Abs(pair[0]-pair[1]) > 1e-6 {
				t.Errorf("%s vs %s %s = %v, want %v", c.a, c.b, name, pair[0], pair[1])
			}
		}
	}
}

func TestNumbersAreSymmetric(t *testing.T) {
	a, b := numbersOf("#f0776a", "#3f8f4f"), numbersOf("#3f8f4f", "#f0776a")
	if a != b {
		t.Fatalf("%+v != %+v", a, b)
	}
}
