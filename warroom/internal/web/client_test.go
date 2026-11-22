package web

import (
	"strings"
	"testing"
	"wargrid/warroom/internal/rounds"
	"wargrid/warroom/internal/stage"
)

func TestShotPageIsTheShownPictureAlone(t *testing.T) {
	a := newGateApp(t)
	whole := a.get("/r/p2-3a1-gate-2/1?shot=1").Body.String()
	mustContain(t, "shot", whole, `class="shot"`, `<iframe`, `--cw:1280`)
	for _, absent := range []string{`id="chips"`, `id="phone"`, "<template", "htmx"} {
		if strings.Contains(whole, absent) {
			t.Errorf("shot page has %s", absent)
		}
	}
	step := a.get("/r/p2-3a1-gate-2/1?shot=1&crop=step").Body.String()
	if strings.Contains(step, `--cw:1280`) {
		t.Error("crop=step still shows the whole frame")
	}
}

func TestShotShowsTheGalleryItem(t *testing.T) {
	a := newShippedApp(t)
	first := a.get("/r/demo/7?shot=1").Body.String()
	second := a.get("/r/demo/7?shot=1&item=notice").Body.String()
	if first == second || !strings.Contains(first, `data-cw`) {
		t.Error("shot ignores item")
	}
}

func TestFoldsStartClosedAndThePhoneFlagRendersTheBar(t *testing.T) {
	a := newGateApp(t)
	desk := a.get("/r/p2-3a1-gate-1/1").Body.String()
	phone := a.get("/r/p2-3a1-gate-1/1?phone=1").Body.String()
	mustContain(t, "desk", desk, `<details class="why">`)
	for _, page := range []string{desk, phone} {
		if strings.Contains(page, `<details class="why" open`) || strings.Contains(page, `<details class="ref" open`) {
			t.Error("a page opens the why or reference fold")
		}
	}
	mustContain(t, "phone", phone, `data-act="sheet"`, `data-act="whole"`, `aria-label="Next step"`, `name="pick" value="A" data-shown`)
}

func TestSheetControlsHaveNoKeys(t *testing.T) {
	body := newShippedApp(t).get("/r/demo-controls/1").Body.String()
	sheet := body[strings.Index(body, `<div class="sheet">`):strings.Index(body, `<div class="row">`)]
	if !strings.Contains(sheet, `hx-get="/r/demo-controls/1?`) || strings.Contains(sheet, "data-key") {
		t.Errorf("sheet controls: %s", sheet)
	}
}

func TestKeyHooks(t *testing.T) {
	a := newShippedApp(t)
	confirm := a.get("/r/demo/2").Body.String()
	mustContain(t, "confirm", confirm, `value="yes" class="pick btn" data-key="enter"`)
	pictures := a.get("/r/demo/1").Body.String()
	mustContain(t, "pictures", pictures, `data-key="enter"`, `data-key="w" data-keepview`, `data-show="A"`, `data-key="a"`)
	mustContain(t, "legend", pictures, `id="legend" hidden`, "Stage controls")
	open := a.get("/r/demo/1?keys=1").Body.String()
	if strings.Contains(open, `id="legend" hidden`) {
		t.Error("keys=1 leaves the legend closed")
	}
}

func TestLegendMarksTheControlsAStepLacks(t *testing.T) {
	round := rounds.LoadCatalog("../../rounds").Round("demo-controls")
	s := &round.Loaded[0]
	l := legendOf(stage.NewStage(round, s, nil), len(s.Pairs) > 0)
	off := map[string]bool{}
	for _, r := range l.Controls {
		off[r.Keys] = r.Off
	}
	if off["S"] || !off["Z"] || !off["N P"] {
		t.Errorf("rows: %v", off)
	}
	if got := legendOf(nil, false); !got.Controls[0].Off {
		t.Error("off a step page every control is off")
	}
}
