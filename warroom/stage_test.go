package main

import (
	"reflect"
	"slices"
	"strings"
	"testing"

	"github.com/goccy/go-yaml"
)

func stageFor(round *Round, s *Step, raw map[string]string) *Stage {
	if raw == nil {
		raw = map[string]string{}
	}
	return newStage(round, s, raw)
}

func statesRound() *Round {
	return &Round{ID: "r", Render: &Render{Pass: map[string]string{"size": "size", "world": "world", "ground": "ground", "hud": "hud", "owner": "you"}}}
}

func controlsStep(c *Controls) *Step {
	return &Step{Key: "s", Kind: "pictures", Controls: c, Options: map[string]Option{"A": {Render: &Render{State: "slab"}}}}
}

func TestDefaultFrameSrcIsTheStatesPage(t *testing.T) {
	st := stageFor(&Round{ID: "r"}, controlsStep(nil), nil)
	got := st.FrameSrc(&Render{State: "slab"})
	if want := "/docs/images/hud-v5/source/p2-3a1-states.html#shot=slab&size=720&scale=1"; got != want {
		t.Fatalf("got %s, want %s", got, want)
	}
}

func TestControlsAddToTheRenderHash(t *testing.T) {
	step := controlsStep(&Controls{Size: &ControlSpec{}, Ground: &ControlSpec{}, World: &ControlSpec{}, Hud: &ControlSpec{}, Owner: &ControlSpec{}, Set: &ControlSpec{}})
	st := stageFor(statesRound(), step, map[string]string{"size": "1920x1080", "ground": "dark", "hud": "off", "owner": "3", "set": "neon", "world": "pile"})
	got := st.FrameSrc(&Render{State: "freeze"})
	want := "/docs/images/hud-v5/source/p2-3a1-states.html#shot=freeze&size=720&scale=1.5&ground=dark&world=pile&hud=0&you=14d45a"
	if got != want {
		t.Fatalf("got %s\nwant %s", got, want)
	}
}

func TestWideWindowPutsItsSizeInTheHash(t *testing.T) {
	step := controlsStep(&Controls{Size: &ControlSpec{}})
	st := stageFor(statesRound(), step, map[string]string{"size": "3440x1440"})
	if got := st.FrameSrc(&Render{State: "slab"}); !strings.HasSuffix(got, "#shot=slab&size=1720x720&scale=2") {
		t.Fatalf("got %s", got)
	}
	z := st.Geometry(&Render{})
	if z.W != 3440 || z.H != 1440 || z.LW != 1720 || z.LH != 720 || z.K != 2 {
		t.Fatalf("geometry %+v", z)
	}
}

func TestValuesOutsideTheListFallBackToTheFirst(t *testing.T) {
	step := controlsStep(&Controls{Zoom: &ControlSpec{Values: []string{"1", "2"}}})
	r := statesRound()
	r.Render.Pass["zoom"] = "zoom"
	for raw, want := range map[string]string{"": "1", "2": "2", "0.5": "1", "nonsense": "1"} {
		if got := stageFor(r, step, map[string]string{"zoom": raw}).Value("zoom"); got != want {
			t.Errorf("zoom=%q -> %q, want %q", raw, got, want)
		}
	}
	if stageFor(r, step, nil).Value("ground") != "" {
		t.Error("a control the step lacks has no value")
	}
}

func TestOptionParamsComeBeforeControlParams(t *testing.T) {
	step := controlsStep(&Controls{Ground: &ControlSpec{}})
	step.Render = &Render{Page: "x/scene.html", Hash: "shot=1", Pass: map[string]string{"ground": "ground"}}
	st := stageFor(&Round{ID: "r"}, step, nil)
	got := st.FrameSrc(&Render{Params: Params{{"glyph", "flat"}, {"ground", "dark"}}})
	if want := "/x/scene.html#shot=1&glyph=flat&ground=sand"; got != want {
		t.Fatalf("got %s, want %s", got, want)
	}
}

func TestExtraControlsUseTheirParam(t *testing.T) {
	step := controlsStep(&Controls{Extra: []ExtraControl{{ID: "view", Values: []ExtraValue{{V: "base"}, {V: "row"}}}, {ID: "cam", Param: "camera", Values: []ExtraValue{{V: "mid"}, {V: "west"}}}}})
	step.Render = &Render{Page: "x/scene.html", Hash: "shot=1"}
	st := stageFor(&Round{ID: "r"}, step, map[string]string{"x-view": "row", "x-cam": "west"})
	if got, want := st.FrameSrc(&Render{}), "/x/scene.html#shot=1&view=row&camera=west"; got != want {
		t.Fatalf("got %s, want %s", got, want)
	}
}

func TestHudLayerOverlaysInsteadOfPassing(t *testing.T) {
	step := controlsStep(&Controls{Hud: &ControlSpec{Values: []string{"slab", "notice"}}})
	st := stageFor(statesRound(), step, map[string]string{"hud": "notice"})
	if strings.Contains(st.FrameSrc(&Render{State: "freeze"}), "hud=") {
		t.Error("an overlay layer is not a render-page parameter")
	}
	if got, want := st.HudLayerSrc(st.Geometry(nil)), "/docs/images/hud-v5/source/p2-3a1-states.html#shot=notice&size=720&scale=1&ground=none"; got != want {
		t.Fatalf("got %s, want %s", got, want)
	}
	if off := stageFor(statesRound(), step, nil); off.HudLayerSrc(off.Geometry(nil)) != "" {
		t.Error("the first value is off")
	}
}

func TestGroundIsOffBehindABackdrop(t *testing.T) {
	step := controlsStep(&Controls{Ground: &ControlSpec{}, World: &ControlSpec{}})
	if !stageFor(statesRound(), step, map[string]string{"world": "pile"}).Disabled("ground") {
		t.Error("ground should be off")
	}
	if stageFor(statesRound(), step, nil).Disabled("ground") {
		t.Error("ground should be on with the plain backdrop")
	}
}

func TestCropKeepsToTheNearerEdge(t *testing.T) {
	z := Geometry{W: 1920, H: 1080, LW: 1280, LH: 720, K: 1.5}
	right := CropFor(&Crop{X: 840, Y: 504, W: 440, H: 216}, 1280, 720, z)
	if right != (Rect{X: 1260, Y: 756, W: 660, H: 324}) {
		t.Fatalf("right crop %+v", right)
	}
	wide := Geometry{W: 3440, H: 1440, LW: 1720, LH: 720, K: 2}
	if left := CropFor(&Crop{X: 0, Y: 0, W: 448, H: 616}, 1280, 720, wide); left != (Rect{X: 0, Y: 0, W: 896, H: 1232}) {
		t.Fatalf("left crop %+v", left)
	}
	if whole := CropFor(nil, 1280, 720, z); whole != (Rect{W: 1920, H: 1080}) {
		t.Fatalf("whole frame %+v", whole)
	}
}

func TestStageStatesCycleThroughTheirList(t *testing.T) {
	step := controlsStep(&Controls{State: &ControlSpec{Values: []string{"a", "b", "c"}}})
	st := stageFor(&Round{ID: "r"}, step, map[string]string{"state": "c"})
	c := st.ctl("state")
	if got := []string{cycle(c, "c", 1), cycle(c, "a", -1)}; !reflect.DeepEqual(got, []string{"a", "c"}) {
		t.Fatalf("cycle = %v", got)
	}
	if got := st.FrameSrc(&Render{}); !strings.Contains(got, "shot=c") {
		t.Fatalf("the state control sets the shot: %s", got)
	}
	if got := st.FrameSrc(&Render{State: "own"}); !strings.Contains(got, "shot=own") {
		t.Fatalf("an option's own state wins: %s", got)
	}
}

func TestFormEscapeFollowsURLSearchParams(t *testing.T) {
	for in, want := range map[string]string{"a b": "a+b", "x=y&z": "x%3Dy%26z", "ü": "%C3%BC", "keep*-._": "keep*-._", "~": "%7E"} {
		if got := formEscape(in); got != want {
			t.Errorf("formEscape(%q) = %q, want %q", in, got, want)
		}
	}
	q := parseOrdered("a=1&b=%2C&a=2")
	q.set("a", "9")
	if got := q.encode(); got != "a=9&b=,&a=2" {
		t.Fatalf("encode = %s", got)
	}
}

func TestParamsKeepYAMLOrderAndHudLayerEscapesLikeJS(t *testing.T) {
	var r Render
	if err := yaml.UnmarshalWithOptions([]byte("params: {zeta: 1, alpha: b}"), &r, yaml.Strict()); err != nil {
		t.Fatal(err)
	}
	if want := (Params{{"zeta", "1"}, {"alpha", "b"}}); !slices.Equal(r.Params, want) {
		t.Fatalf("params = %v", r.Params)
	}
	if err := yaml.Unmarshal([]byte("params: {a: [1]}"), &r); err == nil {
		t.Fatal("a list param must be refused")
	}
	if got := uriComponent("a b+c&(d)*"); got != "a%20b%2Bc%26(d)*" {
		t.Fatalf("uriComponent = %s", got)
	}
}

func TestMarksAppearOnlyWhileTheMarkerIsOn(t *testing.T) {
	step := controlsStep(&Controls{Marker: &ControlSpec{}})
	step.Mark = Marks{{X: 578, Y: 284, W: 124, H: 130, Label: "Small change"}}
	for raw, want := range map[string]int{"": 1, "off": 0} {
		st := stageFor(&Round{ID: "r"}, step, map[string]string{"marker": raw})
		opt := step.Options["A"]
		pic := picBuilder{st: st}.pic(opt.src(), nil, "A", true)
		if len(pic.Marks) != want {
			t.Errorf("marker=%q: %d marks, want %d", raw, len(pic.Marks), want)
		}
	}
}
