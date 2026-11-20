package web

import (
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const tuneStepYAML = `kind: tune
question: Tune it?
neutral: None of these
target: {page: static/demo/scene.html, hash: shot=1}
params:
- {id: outline, label: Outline, min: 0, max: 4, step: 0.5, value: 1}
- {id: unit, label: Unit size, min: 0.5, max: 2, step: 0.1, value: 1}
- {id: you, label: Owner colour, color: '#376eac'}
- {id: ground, label: Ground, values: [sand, dark], value: sand}
`

func newTuneApp(t *testing.T) *testApp {
	t.Helper()
	return newAppWith(t, map[string]string{
		"index.yaml":   "- {id: t, title: Round T}\n",
		"t/round.yaml": "prefix: tt\ntitle: Round T\nsteps: [tune]\n",
		"t/tune.yaml":  tuneStepYAML,
	})
}

func tuneForm(pick, value string) url.Values { return url.Values{"pick": {pick}, "value": {value}} }

const goodValue = `{"outline":1.5,"unit":1.2,"you":"#B04A3A","ground":"dark"}`

func TestTuneRejectsBadValuesAndWritesNothing(t *testing.T) {
	a := newTuneApp(t)
	cases := []struct{ name, value string }{
		{"out of range", `{"outline":9,"unit":1,"you":"#376eac","ground":"sand"}`},
		{"off the step", `{"outline":1.23,"unit":1,"you":"#376eac","ground":"sand"}`},
		{"unknown id", `{"outline":1,"unit":1,"you":"#376eac","ground":"sand","extra":1}`},
		{"renamed id", `{"outline":1,"size":1,"you":"#376eac","ground":"sand"}`},
		{"missing id", `{"outline":1,"unit":1,"you":"#376eac"}`},
		{"bad colour", `{"outline":1,"unit":1,"you":"red","ground":"sand"}`},
		{"short colour", `{"outline":1,"unit":1,"you":"#376ea","ground":"sand"}`},
		{"number as string", `{"outline":"1","unit":1,"you":"#376eac","ground":"sand"}`},
		{"choice as number", `{"outline":1,"unit":1,"you":"#376eac","ground":1}`},
		{"unlisted choice", `{"outline":1,"unit":1,"you":"#376eac","ground":"lava"}`},
		{"too big", `{"outline":1,"unit":1,"you":"#376eac","ground":"sand","pad":"` + strings.Repeat("x", 1024) + `"}`},
		{"not json", `outline=1`},
		{"an array", `[1,2,3,4]`},
		{"null", `null`},
		{"empty", ``},
	}
	for _, tc := range cases {
		wantStatus(t, a.post("/r/t/tune/pick", tuneForm("tuned", tc.value)), 400)
	}
	if _, err := os.Stat(a.picks); !os.IsNotExist(err) {
		t.Fatalf("a refused pick wrote the picks file: %v", err)
	}
	wantStatus(t, a.post("/r/t/tune/pick", url.Values{"pick": {"tuned"}}), 400)
	wantStatus(t, a.post("/r/t/tune/pick", tuneForm("A", goodValue)), 400)
}

func TestTunePickStoresTheCleanedValue(t *testing.T) {
	a := newTuneApp(t)
	wantStatus(t, a.post("/r/t/tune/pick", tuneForm("tuned", `{"outline":1.5000000000000002,"unit":1.2000000000000002,"you":"#B04A3A","ground":"dark"}`)), 303)
	e := a.saved(t)["tt:tune"]
	if e.Pick == nil || *e.Pick != "tuned" {
		t.Fatalf("entry = %+v", e)
	}
	want := map[string]any{"outline": 1.5, "unit": 1.2, "you": "#b04a3a", "ground": "dark"}
	for k, v := range want {
		if e.Value[k] != v {
			t.Errorf("value[%s] = %v, want %v", k, e.Value[k], v)
		}
	}
	if len(e.Value) != len(want) {
		t.Errorf("value = %v", e.Value)
	}
}

func TestTuneNeutralAnswerStoresNoValueAndNoteKeepsIt(t *testing.T) {
	a := newTuneApp(t)
	wantStatus(t, a.post("/r/t/tune/pick", tuneForm("tuned", goodValue)), 303)
	wantStatus(t, a.post("/r/t/tune/note", url.Values{"note": {"later"}}), 200)
	if e := a.saved(t)["tt:tune"]; len(e.Value) != 4 || e.Note != "later" {
		t.Fatalf("a note must keep the value: %+v", e)
	}
	wantStatus(t, a.post("/r/t/tune/pick", url.Values{"pick": {"neither"}}), 303)
	if e := a.saved(t)["tt:tune"]; *e.Pick != "neither" || e.Value != nil {
		t.Fatalf("neither keeps no value: %+v", e)
	}
}

func TestTuneStepPrintsTheIslandAndStartsFromTheRecordedValue(t *testing.T) {
	a := newTuneApp(t)
	body := a.get("/r/t/1").Body.String()
	mustContain(t, "fresh step", body, `<wr-tune data-params="`, `data-field="tune-value"`, `name="value" form="answer" value="{&#34;ground&#34;:&#34;sand&#34;,&#34;outline&#34;:1,&#34;unit&#34;:1,&#34;you&#34;:&#34;#376eac&#34;}"`,
		`src="/static/demo/scene.html#shot=1&amp;outline=1&amp;unit=1&amp;you=%23376eac&amp;ground=sand"`, `value="tuned"`, "None of these")
	_, frame, _ := strings.Cut(body, `<iframe id="`)
	frame, _, _ = strings.Cut(frame, `"`)
	if !strings.Contains(body, `data-target="`+frame+`"`) {
		t.Errorf("data-target must be the frame id %s", frame)
	}

	wantStatus(t, a.post("/r/t/tune/pick", tuneForm("tuned", goodValue)), 303)
	body = a.get("/r/t/1").Body.String()
	mustContain(t, "reopened", body, `&#34;outline&#34;:1.5`, `&#34;you&#34;:&#34;#b04a3a&#34;`, `outline=1.5&amp;unit=1.2&amp;you=%23b04a3a&amp;ground=dark`)
}

func TestTuneIgnoresARecordedValueThatNoLongerFits(t *testing.T) {
	a := newTuneApp(t)
	stale := `{"tt:tune": {"pick": "tuned", "note": "", "value": {"outline": 99, "gone": 1}}}`
	if err := os.MkdirAll(filepath.Dir(a.picks), 0o750); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(a.picks, []byte(stale), 0o600); err != nil {
		t.Fatal(err)
	}
	mustContain(t, "stale value", a.get("/r/t/1").Body.String(), `outline=1&amp;unit=1&amp;you=%23376eac&amp;ground=sand`)
}

func TestTuneSummaryShowsTheValueCompactly(t *testing.T) {
	a := newTuneApp(t)
	wantStatus(t, a.post("/r/t/tune/pick", tuneForm("tuned", goodValue)), 303)
	body := a.get("/r/t/summary").Body.String()
	mustContain(t, "summary", body, "outline 1.5 · unit 1.2 · you #b04a3a · ground dark")
	wantStatus(t, a.post("/r/t/tune/pick", url.Values{"pick": {"neither"}}), 303)
	if body := a.get("/r/t/summary").Body.String(); strings.Contains(body, "outline 1.5") || !strings.Contains(body, "None of these") {
		t.Fatalf("summary after a neutral answer: %s", body)
	}
}

func TestTuneStepPhoneBarPicksTheTunedValue(t *testing.T) {
	a := newTuneApp(t)
	mustContain(t, "phone", a.get("/r/t/1?phone=1").Body.String(), `value="tuned" class="pick btn">Use these</button>`)
}

func TestIslandBundleIsServed(t *testing.T) {
	a := newTuneApp(t)
	rec := a.get("/static/islands.js")
	wantStatus(t, rec, 200)
	if !strings.Contains(rec.Body.String(), "wr-tune") {
		t.Fatal("islands.js does not define wr-tune")
	}
	mustContain(t, "document", a.get("/r/t/1").Body.String(), `<script type="module" src="/static/islands.js">`)
}
