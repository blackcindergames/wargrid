package web

import (
	"testing"
	"wargrid/warroom/internal/rounds"
	"wargrid/warroom/internal/stage"
)

func TestMarksAppearOnlyWhileTheMarkerIsOn(t *testing.T) {
	step := &rounds.Step{
		Key: "s", Kind: "pictures", Controls: &rounds.Controls{Marker: &rounds.ControlSpec{}},
		Options: map[string]rounds.Option{"A": {Render: &rounds.Render{State: "slab"}}},
		Mark:    rounds.Marks{{X: 578, Y: 284, W: 124, H: 130, Label: "Small change"}},
	}
	for raw, want := range map[string]int{"": 1, "off": 0} {
		st := stage.NewStage(&rounds.Round{ID: "r"}, step, map[string]string{"marker": raw})
		opt := step.Options["A"]
		pic := picBuilder{st: st}.pic(optionSrc(&opt), nil, "A", true)
		if len(pic.Marks) != want {
			t.Errorf("marker=%q: %d marks, want %d", raw, len(pic.Marks), want)
		}
	}
}
