package rounds

import (
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
	"wargrid/warroom/internal/store"
)

func writeTree(t *testing.T, files map[string]string) string {
	t.Helper()
	dir := t.TempDir()
	for name, text := range files {
		path := filepath.Join(dir, name)
		if err := os.MkdirAll(filepath.Dir(path), 0o750); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte(text), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	return dir
}

// oneRound is a round "r" holding the given steps, listed in the index.
func oneRound(t *testing.T, roundYAML string, steps map[string]string) *Catalog {
	t.Helper()
	files := map[string]string{
		"index.yaml":     "- {id: r, title: R}\n- {id: old, title: Old}\n",
		"r/round.yaml":   roundYAML,
		"old/round.yaml": "title: Old\nsteps: [first]\n",
		"old/first.yaml": "kind: pictures\noptions: {A: {name: a}}\n",
	}
	for key, text := range steps {
		files["r/"+key+".yaml"] = text
	}
	return LoadCatalog(writeTree(t, files))
}

func hasError(c *Catalog, part string) bool {
	return slices.ContainsFunc(c.Errors, func(e string) bool { return strings.Contains(e, part) })
}

const pictureStep = "kind: pictures\nrec: A\noptions:\n  A: {name: a, img: x.png}\n  B: {name: b, img: y.png}\n"

func TestShippedRoundsLoadClean(t *testing.T) {
	c := LoadCatalog("../../rounds")
	if len(c.Errors) > 0 {
		t.Fatalf("errors:\n%s", strings.Join(c.Errors, "\n"))
	}
	if len(c.Index) != 6 || len(c.Rounds) != 6 {
		t.Fatalf("index %d, rounds %d, want 6 and 6", len(c.Index), len(c.Rounds))
	}
}

func TestShippedRoundsKeepTheirKeyPrefixes(t *testing.T) {
	c := LoadCatalog("../../testdata/rounds")
	want := map[string]string{"p2-3a1-gate-1": "p2-3a1-gate", "p2-3a1-gate-2": "p2-3a1-gate2", "mini-demo": "mini-demo"}
	for id, prefix := range want {
		if got := c.Round(id).Prefix; got != prefix {
			t.Errorf("round %s prefix %q, want %q", id, got, prefix)
		}
	}
}

func TestShippedRoundsKeepTheirContent(t *testing.T) {
	c, shipped := LoadCatalog("../../testdata/rounds"), LoadCatalog("../../rounds")
	forecast := c.Round("p2-3a1-gate-2").Step("forecast")
	if len(forecast.Pairs) != 9 || forecast.Pairs[1].Kind != "vs" || forecast.Pairs[0].AHex != "#dc948b" {
		t.Errorf("forecast pairs = %+v", forecast.Pairs)
	}
	if !strings.Contains(forecast.Why, "`−700` replaces `short`") || !strings.Contains(forecast.Options["A"].Sees, "`CREDITS 500  POWER 8 / 10`") {
		t.Error("forecast prose changed")
	}
	look := c.Round("p2-3a1-gate-2").Step("look")
	if len(look.Items) != 4 || len(look.Items[0].Mark) != 2 || len(look.Items[1].Mark) != 1 || look.VerdictKey() != "verdict" {
		t.Errorf("gate 2 look = %d items, marks %v", len(look.Items), look.Items[0].Mark)
	}
	if got := c.Round("p2-3a1-gate-2").Earlier; !slices.Equal(got, []string{"p2-3a1-gate-1"}) {
		t.Errorf("earlier = %v", got)
	}
	text := shipped.Round("demo").Step("text")
	if len(text.Card.Lines) != 3 || text.Card.Lines[1] != nil || *text.Card.Lines[0] == "" {
		t.Errorf("card lines = %v", text.Card.Lines)
	}
	scene := shipped.Round("demo-controls").Step("scene")
	if len(scene.Controls.Extra) != 4 || !slices.Equal(scene.Controls.Zoom.Values, []string{"1", "2", "0.5"}) || scene.Controls.Ground.Values != nil {
		t.Errorf("scene controls = %+v", scene.Controls)
	}
	if v := scene.Controls.Extra[3].Values[0].V; v != "on" {
		t.Errorf("an extra value 'on' became %q", v)
	}
	if w := shipped.Round("demo-controls").Step("hud-window"); len(w.Options["C"].Mark) != 1 || w.Options["C"].Render.Crop.W != 560 {
		t.Errorf("hud-window option C = %+v", w.Options["C"])
	}
}

func TestIndexFlagsDemoRounds(t *testing.T) {
	c := LoadCatalog("../../testdata/rounds")
	demos := 0
	for _, e := range c.Index {
		if e.Demo {
			demos++
		}
	}
	if demos != 1 || c.Index[0].ID != "p2-3a1-gate-2" {
		t.Fatalf("demos %d, first %q", demos, c.Index[0].ID)
	}
}

func TestLoadErrors(t *testing.T) {
	cases := []struct {
		name  string
		round string
		steps map[string]string
		want  string
	}{
		{"unknown kind", "steps: [s]\n", map[string]string{"s": "kind: poster\n"}, `unknown kind "poster"`},
		{"no kind", "steps: [s]\n", map[string]string{"s": "question: q\n"}, `unknown kind ""`},
		{"no options", "steps: [s]\n", map[string]string{"s": "kind: text\n"}, "r/s: no options"},
		{"rec not an option", "steps: [s]\n", map[string]string{"s": "kind: pictures\nrec: C\noptions: {A: {name: a}}\n"}, "rec C is not an option"},
		{"option letter I", "steps: [s]\n", map[string]string{"s": "kind: pictures\noptions: {I: {name: a}}\n"}, "option I is not one of A to H"},
		{"uses not a step", "steps: [s]\n", map[string]string{"s": pictureStep + "uses: [nope]\n"}, "uses nope is not a step"},
		{"uses a round not earlier", "steps: [s]\n", map[string]string{"s": pictureStep + "uses: [old/first]\n"}, "uses old/first is not a step"},
		{"verdict clashes with a step", "steps: [s, verdict]\n", map[string]string{
			"s": "kind: gallery\nitems: [{id: a, label: a}]\nverdict: {pass: P, changes: C}\n", "verdict": "kind: verdict\n",
		}, "verdict key verdict is also a step key"},
		{"gallery without items", "steps: [s]\n", map[string]string{"s": "kind: gallery\n"}, "r/s: no items"},
		{"duplicate item", "steps: [s]\n", map[string]string{"s": "kind: gallery\nitems: [{id: a}, {id: a}]\n"}, "item a appears twice"},
		{"wording without fields", "steps: [s]\n", map[string]string{"s": "kind: wording\n"}, "r/s: no fields"},
		{"missing step file", "steps: [s]\n", nil, "[step missing: s]"},
		{"step key escaping the folder", "steps: ['../x']\n", nil, "bad step key"},
		{"duplicate step", "steps: [s, s]\n", map[string]string{"s": pictureStep}, "step s is listed twice"},
		{"earlier not in index", "steps: [s]\nearlier: [ghost]\n", map[string]string{"s": pictureStep}, "earlier round ghost is not in the index"},
		{"unknown step field", "steps: [s]\n", map[string]string{"s": pictureStep + "colour: red\n"}, "colour"},
		{"unknown round field", "steps: []\nbogus: 1\n", nil, "bogus"},
		{"unknown control", "steps: [s]\n", map[string]string{"s": pictureStep + "controls: {sparkle: true}\n"}, "sparkle"},
		{"control false", "steps: [s]\n", map[string]string{"s": pictureStep + "controls: {fit: false}\n"}, "write true or a list"},
		{"control the page does not take", "steps: [s]\n", map[string]string{"s": pictureStep + "controls: {ground: true}\n"}, "control ground does nothing here"},
		{"control value not allowed", "steps: [s]\n", map[string]string{"s": pictureStep + "controls: {zoom: ['3']}\nrender: {pass: {zoom: zoom}}\n"}, "control zoom has no value 3"},
		{"state without a list", "steps: [s]\n", map[string]string{"s": pictureStep + "controls: {state: true}\n"}, "control state needs a list"},
		{"extra without values", "steps: [s]\n", map[string]string{"s": pictureStep + "controls: {extra: [{id: v, label: V}]}\n"}, "extra control needs id and values"},
		{"extra key taken", "steps: [s]\n", map[string]string{"s": pictureStep + "controls: {extra: [{id: v, key: g, values: [{v: a, label: A}]}]}\n"}, "extra control v key g is taken by the app"},
		{"bad pair", "steps: [s]\n", map[string]string{"s": pictureStep + "pairs: [[a, red, b, '#000000']]\n"}, "colours must be #rrggbb"},
	}
	for _, k := range []string{"5", "6", "7", "8"} {
		cases = append(cases, struct {
			name  string
			round string
			steps map[string]string
			want  string
		}{"extra key " + k + " picks an option", "steps: [s]\n", map[string]string{"s": pictureStep + "controls: {extra: [{id: v, key: '" + k + "', values: [{v: a, label: A}]}]}\n"}, "extra control v key " + k + " is taken by the app"})
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			c := oneRound(t, tc.round, tc.steps)
			if !hasError(c, tc.want) {
				t.Fatalf("want an error containing %q, got %q", tc.want, c.Errors)
			}
		})
	}
}

func TestValidStepsAndControlsLoadClean(t *testing.T) {
	step := pictureStep + "uses: [old/first]\nmark: {x: 1, y: 2, w: 3, h: 4, label: here}\npairs: [[a, '#000000', b, '#ffffff', vs]]\n" +
		"controls: {zoom: ['1', '2'], hud: [slab], state: [one, two], set: true, owner: true, extra: [{id: v, key: v, values: [{v: a, label: A}]}]}\n" +
		"render: {pass: {zoom: zoom, owner: you}}\n"
	c := oneRound(t, "steps: [s]\nearlier: [old]\n", map[string]string{"s": step})
	if len(c.Errors) > 0 {
		t.Fatalf("errors: %q", c.Errors)
	}
	s := c.Round("r").Step("s")
	if len(s.Mark) != 1 || s.Mark[0].Label != "here" || s.Pairs[0].Kind != "vs" {
		t.Fatalf("step = %+v", s)
	}
}

func TestEightOptionsAndAnIntroLoad(t *testing.T) {
	step := "kind: pictures\noptions:\n"
	for _, l := range "ABCDEFGH" {
		step += "  " + string(l) + ": {name: n" + string(l) + "}\n"
	}
	c := oneRound(t, "steps: [s]\nintro: Judge on a laptop; neutral ships as A.\n", map[string]string{"s": step})
	if len(c.Errors) > 0 {
		t.Fatalf("errors: %q", c.Errors)
	}
	r := c.Round("r")
	if got := r.Step("s").OptionLetters(); !slices.Equal(got, []string{"A", "B", "C", "D", "E", "F", "G", "H"}) {
		t.Errorf("letters = %v", got)
	}
	if r.Intro != "Judge on a laptop; neutral ships as A." {
		t.Errorf("intro = %q", r.Intro)
	}
}

func TestRoundsSharingAPrefixAreALoadError(t *testing.T) {
	c := LoadCatalog(writeTree(t, map[string]string{
		"index.yaml":   "- {id: a, title: A}\n- {id: b, title: B}\n",
		"a/round.yaml": "prefix: same\nsteps: []\n",
		"b/round.yaml": "prefix: same\nsteps: []\n",
	}))
	if !hasError(c, "rounds a and b share the prefix same") {
		t.Fatalf("errors: %q", c.Errors)
	}
}

func TestRoundControlsApplyToItsSteps(t *testing.T) {
	c := oneRound(t, "steps: [s]\ncontrols: {size: true}\nrender: {pass: {size: size}}\n", map[string]string{"s": pictureStep})
	if len(c.Errors) > 0 {
		t.Fatalf("errors: %q", c.Errors)
	}
	c = oneRound(t, "steps: [s]\ncontrols: {size: true}\n", map[string]string{"s": pictureStep})
	if !hasError(c, "control size does nothing here") {
		t.Fatalf("errors: %q", c.Errors)
	}
}

func TestMissingIndexIsAnError(t *testing.T) {
	c := LoadCatalog(t.TempDir())
	if !hasError(c, "index.yaml") || len(c.Rounds) != 0 {
		t.Fatalf("errors %q", c.Errors)
	}
}

func TestOpenSteps(t *testing.T) {
	c := oneRound(t, "steps: [s, g, v, w]\n", map[string]string{
		"s": pictureStep,
		"g": "kind: gallery\nitems: [{id: a, label: a}]\nverdict: {key: gv, pass: P, changes: C}\n",
		"v": "kind: verdict\n",
		"w": "kind: wording\nfields: [{id: f, label: F, text: t}]\n",
	})
	r := c.Round("r")
	if got := r.Open(map[string]store.Entry{}); !slices.Equal(got, []int{0, 1, 2}) {
		t.Fatalf("nothing answered: %v", got)
	}
	a := "A"
	entries := map[string]store.Entry{"r:s": {Pick: &a}, "r:gv": {Pick: &a}, "r:v": {Note: "only a note"}}
	if got := r.Open(entries); !slices.Equal(got, []int{2}) {
		t.Fatalf("a note is not an answer: %v", got)
	}
}

func TestAcceptsPick(t *testing.T) {
	step := func(s Step) *Step { return &s }
	two := map[string]Option{"A": {}, "B": {}}
	cases := []struct {
		name string
		s    *Step
		pick string
		want bool
	}{
		{"option letter", step(Step{Kind: "pictures", Options: two}), "B", true},
		{"missing letter", step(Step{Kind: "pictures", Options: two}), "C", false},
		{"neither without neutral", step(Step{Kind: "pictures", Options: two}), "neither", false},
		{"neither with neutral", step(Step{Kind: "pictures", Options: two, Neutral: "None"}), "neither", true},
		{"yes on a confirm step", step(Step{Kind: "pictures", Options: map[string]Option{"A": {}}}), "yes", true},
		{"yes on a two-option step", step(Step{Kind: "pictures", Options: two}), "yes", false},
		{"change on a confirm step", step(Step{Kind: "pictures", Options: map[string]Option{"A": {}}}), "change", true},
		{"verdict pass", step(Step{Kind: "verdict"}), "pass", true},
		{"verdict letter", step(Step{Kind: "verdict"}), "A", false},
		{"gallery with a verdict", step(Step{Kind: "gallery", Verdict: &Verdict{}}), "changes", true},
		{"gallery without a verdict", step(Step{Kind: "gallery"}), "pass", false},
		{"wording", step(Step{Kind: "wording"}), "A", false},
		{"tuned on a tune step", step(Step{Kind: "tune"}), "tuned", true},
		{"tuned on a pictures step", step(Step{Kind: "pictures", Options: two}), "tuned", false},
		{"letter on a tune step", step(Step{Kind: "tune"}), "A", false},
		{"neither on a tune step with a neutral", step(Step{Kind: "tune", Neutral: "None"}), "neither", true},
		{"neither on a tune step without one", step(Step{Kind: "tune"}), "neither", false},
		{"empty", step(Step{Kind: "pictures", Options: two}), "", false},
	}
	for _, tc := range cases {
		if got := tc.s.AcceptsPick(tc.pick); got != tc.want {
			t.Errorf("%s: AcceptsPick(%q) = %v", tc.name, tc.pick, got)
		}
	}
}

func TestLoaderWarnsWhenEveryBlindStepHasTheSameLetter(t *testing.T) {
	blind := func(rec string) string { return strings.Replace(pictureStep, "rec: A", "rec: "+rec+"\nblind: true", 1) }
	const warning = "every blind step has Claude's pick at"
	same := oneRound(t, "steps: [a, b, open]\n", map[string]string{"a": blind("B"), "b": blind("B"), "open": pictureStep})
	if want := []string{"r: " + warning + " B; vary the letter"}; !slices.Equal(same.Warnings, want) || len(same.Errors) > 0 {
		t.Errorf("same letter: warnings %q, errors %q; want warnings %q, no errors", same.Warnings, same.Errors, want)
	}
	for name, steps := range map[string]map[string]string{
		"varied":     {"a": blind("A"), "b": blind("B"), "open": pictureStep},
		"one blind":  {"a": blind("B"), "b": pictureStep, "open": pictureStep},
		"none blind": {"a": pictureStep, "b": pictureStep, "open": pictureStep},
	} {
		if c := oneRound(t, "steps: [a, b, open]\n", steps); len(c.Warnings) > 0 {
			t.Errorf("%s: %q", name, c.Warnings)
		}
	}
}

func longStep(question, notes, look string) string {
	return "kind: pictures\nquestion: " + question + "\nlook: " + look + "\noptions:\n  A: {name: a, img: x.png}\n  B: {name: b, img: y.png, notes: " + notes + "}\n"
}

func TestLongTextsWarnTheAuthor(t *testing.T) {
	step := longStep(strings.Repeat("q", 71), strings.Repeat("n", 91), strings.Repeat("l", 121))
	c := oneRound(t, "steps: [a]\n", map[string]string{"a": step})
	want := []string{
		"r/a option B: notes is 91 characters; keep it to one line (90)",
		"r/a: look is 121 characters; keep it to one line (120)",
		"r/a: question is 71 characters; keep it to one line (70)",
	}
	if !slices.Equal(c.Warnings, want) || len(c.Errors) > 0 {
		t.Errorf("warnings %q, errors %q; want warnings %q, no errors", c.Warnings, c.Errors, want)
	}
}

func TestTextsAtTheLimitDoNotWarn(t *testing.T) {
	question := strings.Repeat("q", 30) + "`" + strings.Repeat("q", 40) + "`"
	step := longStep(question, strings.Repeat("n", 90), strings.Repeat("l", 120))
	c := oneRound(t, "steps: [a]\n", map[string]string{"a": step})
	if len(c.Warnings) > 0 || len(c.Errors) > 0 {
		t.Errorf("warnings %q, errors %q; want none", c.Warnings, c.Errors)
	}
}
