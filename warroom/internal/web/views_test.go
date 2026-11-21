package web

import (
	"fmt"
	"html"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"wargrid/warroom/internal/rounds"
)

func newShippedApp(t *testing.T) *testApp {
	t.Helper()
	picks := filepath.Join(t.TempDir(), "picks.json")
	srv := NewServer(&Config{Root: "../../..", Picks: picks, Rounds: "../../rounds"})
	return &testApp{Server: srv, h: srv.Routes(), picks: picks}
}

// newGateApp serves the retired P2.3a1 gate rounds, kept as fixtures for what the demos lack: earlier rounds, marks, pairs.
func newGateApp(t *testing.T) *testApp {
	t.Helper()
	picks := filepath.Join(t.TempDir(), "picks.json")
	srv := NewServer(&Config{Root: "../../..", Picks: picks, Rounds: "../../testdata/rounds"})
	return &testApp{Server: srv, h: srv.Routes(), picks: picks}
}

func (a *testApp) fragment(method, target string, form url.Values) *httptest.ResponseRecorder {
	var req *http.Request
	if method == http.MethodPost {
		req = httptest.NewRequest(method, target, strings.NewReader(form.Encode()))
		req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	} else {
		req = httptest.NewRequest(method, target, nil)
	}
	req.Header.Set("HX-Request", "true")
	req.Header.Set("HX-Request-Type", "partial")
	rec := httptest.NewRecorder()
	a.h.ServeHTTP(rec, req)
	return rec
}

func text(s string) string { return html.EscapeString(unmark(s)) }

var boldSpans = strings.NewReplacer(`<span class="w">`, "", "</span>", "")

func mustContain(t *testing.T, where, body string, parts ...string) {
	t.Helper()
	for _, p := range parts {
		if !strings.Contains(body, p) {
			t.Errorf("%s: missing %q", where, p)
		}
	}
}

func TestEveryShippedStepRendersWithItsQuestionOptionsAndEndpoints(t *testing.T) {
	a := newShippedApp(t)
	c := rounds.LoadCatalog("../../rounds")
	steps := 0
	for id, round := range c.Rounds {
		for i := range round.Loaded {
			s := &round.Loaded[i]
			target := fmt.Sprintf("/r/%s/%d", id, i+1)
			rec := a.get(target)
			if rec.Code != 200 {
				t.Errorf("GET %s = %d", target, rec.Code)
				continue
			}
			body := boldSpans.Replace(rec.Body.String())
			steps++
			mustContain(t, target, body, text(s.Question), `href="/r/`+id+`/summary"`)
			if strings.Contains(body, `id="err"`) {
				t.Errorf("%s shows an error banner", target)
			}
			if s.IsChoice() {
				mustContain(t, target, body, `action="/r/`+id+`/`+s.Key+`/pick"`, `hx-post="/r/`+id+`/`+s.Key+`/note"`)
				for _, l := range s.OptionLetters() {
					mustContain(t, target, body, `data-opt="`+l+`"`, text(s.Options[l].Name))
				}
			}
		}
		if rec := a.get("/r/" + id + "/summary"); rec.Code != 200 || !strings.Contains(rec.Body.String(), "What the server recorded") {
			t.Errorf("summary of %s = %d", id, rec.Code)
		}
	}
	if steps < 15 {
		t.Fatalf("only %d steps rendered", steps)
	}
}

func TestHtmxGetsTheFragmentAndABrowserGetsTheDocument(t *testing.T) {
	a := newApp(t)
	full := a.get("/r/r/1")
	mustContain(t, "document", full.Body.String(), "<!doctype html>", `id="page"`, `hx-boost:inherited="true"`)
	frag := a.fragment("GET", "/r/r/1", nil)
	body := frag.Body.String()
	if !strings.HasPrefix(body, "<title>Round R · War Room</title>") || strings.Contains(body, "<!doctype") || !strings.Contains(body, `id="view"`) {
		t.Fatalf("fragment = %.200s", body)
	}
	if !strings.Contains(frag.Header().Get("Vary"), "HX-Request-Type") {
		t.Error("the two renderings must not share a cache entry")
	}
	history := httptest.NewRequest(http.MethodGet, "/r/r/1", nil)
	history.Header.Set("HX-Request", "true")
	history.Header.Set("HX-Request-Type", "full")
	rec := httptest.NewRecorder()
	a.h.ServeHTTP(rec, history)
	if !strings.Contains(rec.Body.String(), "<!doctype html>") {
		t.Error("a history restore needs the whole document")
	}
}

func TestPickRoundTripWritesTheGateKeyAndMovesOn(t *testing.T) {
	a := newGateApp(t)
	rec := a.post("/r/p2-3a1-gate-1/unload/pick", url.Values{"pick": {"B"}})
	wantStatus(t, rec, http.StatusSeeOther)
	if loc := rec.Header().Get("Location"); loc != "/r/p2-3a1-gate-1/2" {
		t.Fatalf("location %q", loc)
	}
	if e := a.saved(t)["p2-3a1-gate:unload"]; e.Pick == nil || *e.Pick != "B" {
		t.Fatalf("saved = %+v", a.saved(t))
	}
}

func TestHtmxPickAnswersWithTheNextStepAndPushesItsAddress(t *testing.T) {
	a := newApp(t)
	rec := a.fragment("POST", "/r/r/pic/pick?size=1920x1080&numbers=0", url.Values{"pick": {"B"}, "note": {"closer"}})
	wantStatus(t, rec, 200)
	push := rec.Header().Get("HX-Push-Url")
	if push != "/r/r/2?numbers=0&size=1920x1080" {
		t.Fatalf("push url %q: the controls stay page-wide", push)
	}
	body := rec.Body.String()
	mustContain(t, "next step", body, "<title>", "Right as drawn?", "Recorded: pic B.", `1 pic · B`)
	if e := a.saved(t)["pre:pic"]; *e.Pick != "B" || e.Note != "closer" {
		t.Fatalf("entry %+v", e)
	}
}

func TestLastPickLandsOnTheSummary(t *testing.T) {
	a := newApp(t)
	rec := a.fragment("POST", "/r/r/ver/pick", url.Values{"pick": {"pass"}})
	if push := rec.Header().Get("HX-Push-Url"); push != "/r/r/summary" && !strings.HasPrefix(push, "/r/r/5") {
		t.Fatalf("push %q", push)
	}
	gal := a.fragment("POST", "/r/r/gal/pick", url.Values{"pick": {"changes"}})
	if push := gal.Header().Get("HX-Push-Url"); push != "/r/r/summary" {
		t.Fatalf("a gallery verdict goes to the summary, got %q", push)
	}
	mustContain(t, "summary", gal.Body.String(), "What the server recorded", "Verdict", "Not answered yet")
}

func TestChangeNeedsANote(t *testing.T) {
	a := newApp(t)
	rec := a.fragment("POST", "/r/r/conf/pick", url.Values{"pick": {"change"}, "note": {"  "}})
	wantStatus(t, rec, 200)
	mustContain(t, "hint", rec.Body.String(), "Say what to change here, then press Change again.", "Right as drawn?", " autofocus")
	if got := rec.Header().Get("HX-Reswap"); got != "innerHTML" {
		t.Errorf("HX-Reswap = %q: show:top would scroll the hint away", got)
	}
	if rec.Header().Get("HX-Push-Url") != "" {
		t.Error("the page stays where it is")
	}
	if _, err := os.Stat(a.picks); !os.IsNotExist(err) {
		t.Fatal("nothing is recorded without the note")
	}
	wantStatus(t, a.post("/r/r/conf/pick", url.Values{"pick": {"change"}, "note": {"the glyph"}}), http.StatusSeeOther)
}

func TestBlindStepRevealsAfterThePick(t *testing.T) {
	a := newShippedApp(t)
	before := a.get("/r/demo/1").Body.String()
	if strings.Contains(before, "tag rv") {
		t.Fatal("the reveal shows before the pick")
	}
	rec := a.fragment("POST", "/r/demo/pictures/pick", url.Values{"pick": {"A"}})
	mustContain(t, "pick line", rec.Body.String(), "Recorded: pictures A. A was today&#39;s look.")
	after := a.get("/r/demo/1").Body.String()
	mustContain(t, "revealed", after, `tag rv">today&#39;s look`, `tag got">Picked`)
}

func TestBlindStepHidesClaudesPickUntilThePick(t *testing.T) {
	a := newShippedApp(t)
	before := a.get("/r/demo/1").Body.String()
	for _, leak := range []string{"Claude's pick", "Claude's reason", `value="B" data-shown`} {
		if strings.Contains(before, leak) {
			t.Errorf("before the pick the blind step shows %s", leak)
		}
	}
	mustContain(t, "opens on A", before, `value="A" data-shown`)
	if uses := a.get("/r/demo/2").Body.String(); strings.Contains(uses, "shown with B") {
		t.Error("a step using the blind step names Claude's pick before the pick")
	}
	wantStatus(t, a.post("/r/demo/pictures/pick", url.Values{"pick": {"C"}}), http.StatusSeeOther)
	mustContain(t, "after the pick", a.get("/r/demo/1").Body.String(), `class="cpwhy"`, "B: Backdrop two", `class="tag cp ptab" data-cp="B"`)
}

func TestConfirmStepTagsNoOption(t *testing.T) {
	body := newShippedApp(t).get("/r/demo/2").Body.String()
	mustContain(t, "confirm", body, `class="cpwhy"`, "Yes, as drawn")
	if n := strings.Count(body, `tag cp`); n != 0 {
		t.Errorf("%d Claude's-pick tags or tabs, want none: Claude's reason says it", n)
	}
}

func TestNotePostAnswersWithTheRecordLine(t *testing.T) {
	a := newApp(t)
	rec := a.post("/r/r/gal/note", url.Values{"note": {"blurry"}, "sub": {"a"}})
	wantStatus(t, rec, 200)
	if rec.Body.String() != "Recorded: note on gal:a." {
		t.Fatalf("body %q", rec.Body.String())
	}
	body := a.get("/r/r/3?item=a").Body.String()
	mustContain(t, "gallery", body, ">blurry</textarea>", `class="th on noted"`)
}

func TestPickBodyDoesNotLoseTheSavedNote(t *testing.T) {
	a := newApp(t)
	wantStatus(t, a.post("/r/r/pic/note", url.Values{"note": {"first thought"}}), 200)
	body := a.get("/r/r/1").Body.String()
	mustContain(t, "step", body, ">first thought</textarea>")
}

func TestSummaryListsRowsOpenStepsAndClosesWhenDone(t *testing.T) {
	a := newApp(t)
	wantStatus(t, a.post("/r/r/pic/pick", url.Values{"pick": {"neither"}, "note": {"both fine"}}), 303)
	body := a.get("/r/r/summary").Body.String()
	mustContain(t, "partial", body, "1 of 4 answered", "Which one?", "Neither", "both fine", "Not answered yet", `href="/r/r/2"`, "- Which one?: Neither | both fine")
	if strings.Contains(body, "You can close this tab.") {
		t.Fatal("not everything is answered")
	}
	for _, p := range []struct{ step, pick string }{{"conf", "yes"}, {"gal", "pass"}, {"ver", "pass"}} {
		wantStatus(t, a.post("/r/r/"+p.step+"/pick", url.Values{"pick": {p.pick}}), 303)
	}
	body = a.get("/r/r/summary").Body.String()
	mustContain(t, "done", body, "You can close this tab.", "4 of 4 answered", "Yes, as drawn")
	if strings.Contains(body, "Not answered yet") {
		t.Fatal("nothing is open any more")
	}
}

func TestSummaryShowsEarlierRounds(t *testing.T) {
	a := newGateApp(t)
	wantStatus(t, a.post("/r/p2-3a1-gate-1/unload/pick", url.Values{"pick": {"A"}}), 303)
	if c := rounds.LoadCatalog("../../testdata/rounds"); len(c.Rounds["p2-3a1-gate-2"].Earlier) == 0 {
		t.Skip("the second gate round lists no earlier round")
	}
	body := a.get("/r/p2-3a1-gate-2/summary").Body.String()
	mustContain(t, "earlier", body, "Earlier rounds", "P2.3a1 gate A, round 1")
}

func TestStepNavigationWrapsThroughTheSummary(t *testing.T) {
	a := newApp(t)
	first := a.get("/r/r/1").Body.String()
	mustContain(t, "first", first, `href="/r/r/summary" data-key="arrowleft"`, `href="/r/r/2" data-key="arrowright"`)
	last := a.get("/r/r/5").Body.String()
	mustContain(t, "last", last, `href="/r/r/4" data-key="arrowleft"`, `href="/r/r/summary" data-key="arrowright"`, "Summary")
	sum := a.get("/r/r/summary").Body.String()
	mustContain(t, "summary", sum, `href="/r/r/5" data-key="arrowleft"`, `href="/r/r/1" data-key="arrowright"`, "Step 1")
}

func TestControlsStayPageWideInLinksAndRenderHashes(t *testing.T) {
	a := newShippedApp(t)
	body := a.get("/r/demo-controls/1?size=1920x1080&cvd=deut&numbers=0").Body.String()
	mustContain(t, "controls", body,
		`data-cvd="deut"`,
		`href="/r/demo-controls/2?cvd=deut&amp;numbers=0&amp;size=1920x1080"`,
		`hx-get="/r/demo-controls/1?cvd=deut&amp;numbers=0&amp;size=3440x1440"`,
		`hx-swap="innerMorph"`, `hx-push-url="true"`,
		`size=720&amp;scale=1.5`,
	)
	if got := a.get("/r/demo-controls/1?fit=100").Body.String(); !strings.Contains(got, `class="view true100"`) {
		t.Error("true 100 % is a class on the view")
	}
}

func TestSideBySideRendersTilesWithOneSharedPick(t *testing.T) {
	a := newShippedApp(t)
	body := a.get("/r/demo/3").Body.String()
	mustContain(t, "text step is side by side", body, `class="tiles"`, `name="pick" value="A" data-shown`, "Numbers read at a glance")
	if strings.Contains(body, `name="pick" value="B"`) {
		t.Error("side by side still has a Pick per tile")
	}
	flip := a.get("/r/demo/3?view=flip").Body.String()
	if strings.Contains(flip, `class="tiles"`) || !strings.Contains(flip, `class="stage"`) {
		t.Error("view=flip overrides the step's side default")
	}
	mustContain(t, "toggle", flip, `data-key="w"`, "Side by side")
}

func TestFlipRendersEveryOptionAndHidesTheOthers(t *testing.T) {
	a := newApp(t)
	body := a.get("/r/r/1?show=B").Body.String()
	mustContain(t, "stage", body, `data-opt="A" hidden`, `class="ostage" data-opt="B">`, `name="pick" value="B" data-shown class="pick btn" data-key="enter"`, "Neither")
	if def := a.get("/r/r/1").Body.String(); !strings.Contains(def, `class="ostage" data-opt="A">`) {
		t.Error("the first option shows by default")
	}
}

func TestPicturesThatExistRenderAndMissingOnesSayWhat(t *testing.T) {
	a := newApp(t)
	body := a.get("/r/r/1").Body.String()
	mustContain(t, "missing", body, "[picture missing: a.png]")
	root := filepath.Join(a.cfg.Root, "docs")
	if err := os.WriteFile(filepath.Join(root, "a.png"), []byte("png"), 0o600); err != nil {
		t.Fatal(err)
	}
	step := filepath.Join(a.cfg.Rounds, "r", "pic.yaml")
	text := "kind: pictures\nquestion: Q\noptions:\n  A: {name: x, img: docs/a.png}\n  B: {name: y, img: docs/nope.png, local: true}\n  C: {name: z, img: tools/t.txt}\n"
	if err := os.WriteFile(step, []byte(text), 0o600); err != nil {
		t.Fatal(err)
	}
	body = a.get("/r/r/1").Body.String()
	mustContain(t, "pictures", body, `<img src="/docs/a.png"`, "Your local file, not published with this page: docs/nope.png", "[picture missing: tools/t.txt]")
}

func TestWordingFieldsStartWithTheDraftAndKeepEdits(t *testing.T) {
	a := newApp(t)
	body := a.get("/r/r/5").Body.String()
	mustContain(t, "draft", body, ">t</textarea>", `hx-vals="{&#34;sub&#34;:&#34;f1&#34;}"`, `hx-post="/r/r/wor/note"`, "Drafted: t")
	wantStatus(t, a.post("/r/r/wor/note", url.Values{"note": {"edited"}, "sub": {"f1"}}), 200)
	mustContain(t, "edited", a.get("/r/r/5").Body.String(), ">edited</textarea>")
}

func TestNoteBoxesCarryTheSyncAndFailureHooks(t *testing.T) {
	a := newApp(t)
	body := a.get("/r/r/1").Body.String()
	mustContain(t, "note", body,
		`hx-trigger="input changed delay:700ms, blur changed"`,
		`hx-sync="#answer:queue last"`, `hx-target="#rec"`, `form="answer"`,
		`id="answer" method="post" action="/r/r/pic/pick"`, `hx-sync="this:queue all"`,
		`hx-status:5xx:inherited="swap:none"`,
	)
}

func TestLoadErrorsStayVisibleInFragments(t *testing.T) {
	a := newApp(t)
	if err := os.Remove(filepath.Join(a.cfg.Rounds, "r", "ver.yaml")); err != nil {
		t.Fatal(err)
	}
	body := a.fragment("GET", "/r/r/1", nil).Body.String()
	mustContain(t, "fragment", body, `id="err"`, "[step missing: ver]")
	mustContain(t, "missing step page", a.get("/r/r/4").Body.String(), "[step missing: ver]", "did not load")
}

func TestUnreadablePicksShowABannerNotAnEmptyPage(t *testing.T) {
	a := newApp(t)
	if err := os.MkdirAll(filepath.Dir(a.picks), 0o750); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(a.picks, []byte("{broken"), 0o600); err != nil {
		t.Fatal(err)
	}
	rec := a.get("/r/r/1")
	wantStatus(t, rec, 200)
	mustContain(t, "banner", rec.Body.String(), "picks file unreadable")
}

func TestPhoneCropAppliesWithThePhoneFlag(t *testing.T) {
	a := newGateApp(t)
	desktop := a.get("/r/p2-3a1-gate-2/1").Body.String()
	phone := a.get("/r/p2-3a1-gate-2/1?phone=1").Body.String()
	if desktop == phone || !strings.Contains(phone, "phone=1") {
		t.Error("the phone flag swaps the crop and stays in the links")
	}
	mustContain(t, "crop", desktop, "data-cw=\""+strconv.Itoa(440)+"\"")
	mustContain(t, "phone crop", phone, "--ar:440/420")
}

func TestLabStartsOnlyOnRequest(t *testing.T) {
	a := newShippedApp(t)
	idle := a.get("/r/demo/6").Body.String()
	mustContain(t, "idle", idle, "Start the lab here", "Open the lab in this tab", `hx-boost="false"`)
	if strings.Contains(idle, "<iframe class=\"labframe\"") {
		t.Fatal("the lab must not load before Start")
	}
	started := a.get("/r/demo/6?lab=1").Body.String()
	mustContain(t, "started", started, `<iframe class="labframe" src="/web/site/index.html"`)
}

func TestDemoSceneIsServedFromTheEmbeddedStatic(t *testing.T) {
	a := newShippedApp(t)
	wantStatus(t, a.get("/static/demo/scene.html"), 200)
	body := a.get("/r/demo-controls/4?x-view=row&owner=2").Body.String()
	mustContain(t, "scene", body, `src="/static/demo/scene.html#shot=1&amp;glyph=flat&amp;ground=sand&amp;zoom=1&amp;you=b04a3a&amp;heading=0&amp;view=row&amp;cam=middle&amp;pair=usa-china&amp;names=on"`)
}

func TestQueryKeepsOnlyKnownControlsAndCarriesThem(t *testing.T) {
	q := parseQuery(url.Values{"size": {"1920x1080"}, "x-view": {"row"}, "show": {"B"}, "evil": {"1"}, "numbers": {"0"}, "phone": {"1"}})
	want := url.Values{"size": {"1920x1080"}, "x-view": {"row"}, "numbers": {"0"}, "phone": {"1"}}
	if got := q.Carry(); got.Encode() != want.Encode() {
		t.Fatalf("carry = %s", got.Encode())
	}
	if got := q.WithCtl("size", "1280x720", "1280x720"); got.Has("size") {
		t.Fatal("the first value needs no parameter")
	}
}

func TestGalleryChipKeyIsOnItsFormAndItemNotes(t *testing.T) {
	a := newGateApp(t)
	body := a.get("/r/p2-3a1-gate-1/4").Body.String()
	mustContain(t, "gallery", body, `data-step="verdict" hidden`, `data-note="look:`, `data-chip="verdict"`)
	if n := strings.Count(body, `data-step="verdict"`); n != 2 {
		t.Fatalf("the chip and the form share the verdict key: %d", n)
	}
}

func TestFramesGetAnIDThatFollowsTheirAddress(t *testing.T) {
	a := newShippedApp(t)
	id := func(q string) string {
		body := a.get("/r/demo-controls/2" + q).Body.String()
		at := strings.Index(body, `<iframe id="`)
		if at < 0 {
			t.Fatalf("no frame id in %s", q)
		}
		return body[at : at+30]
	}
	if id("") != id("?cvd=deut") {
		t.Error("an app-side control must keep the frame")
	}
	if id("") == id("?ground=dark") {
		t.Error("a control that changes the address must change the frame id")
	}
}

func TestQueryDropsLongOddAndTooManyControlValues(t *testing.T) {
	v := url.Values{"size": {strings.Repeat("x", 65)}, "ground": {"<b>"}, "zoom": {"0.5"}}
	for i := range 20 {
		v.Set("x-k"+strconv.Itoa(i), "v")
	}
	q := parseQuery(v)
	if _, ok := q.Ctl["size"]; ok {
		t.Fatal("a 65-byte value must be dropped")
	}
	if _, ok := q.Ctl["ground"]; ok {
		t.Fatal("a value with unsafe characters must be dropped")
	}
	if q.Ctl["zoom"] != "0.5" || len(q.Ctl) != 1+maxExtraCtls {
		t.Fatalf("ctl = %v", q.Ctl)
	}
	a := newShippedApp(t)
	page := a.get("/r/demo-controls/2?ground=" + strings.Repeat("d", 300000))
	wantStatus(t, page, 200)
	if n := page.Body.Len(); n > 200000 {
		t.Fatalf("a long query value must not reach the page's links: %d bytes", n)
	}
}

func manyOptionsApp(t *testing.T) *testApp {
	t.Helper()
	step := "kind: pictures\nquestion: Which of six?\noptions:\n"
	for _, l := range "ABCDEF" {
		step += "  " + string(l) + ": {name: n" + string(l) + ", img: docs/a.txt}\n"
	}
	return newAppWith(t, map[string]string{
		"index.yaml":   "- {id: m, title: Round M}\n",
		"m/round.yaml": "title: Round M\nintro: Judge at 100 %; a neutral answer ships option A.\nsteps: [six, txt, ref4]\n",
		"m/ref4.yaml":  "kind: pictures\nquestion: Against today?\nref: {label: Today, img: docs/a.txt}\noptions:\n  A: {name: a, img: docs/a.txt}\n  B: {name: b, img: docs/a.txt}\n  C: {name: c, img: docs/a.txt}\n  D: {name: d, img: docs/a.txt}\n",
		"m/six.yaml":   step,
		"m/txt.yaml":   "kind: text\nquestion: Which words?\noptions: {A: {name: a, text: one}, B: {name: b, text: two}}\n",
	})
}

func TestOptionsPastDFlipWithDigitsOnlyAndSideBySideWraps(t *testing.T) {
	a := manyOptionsApp(t)
	body := a.get("/r/m/1").Body.String()
	mustContain(t, "flip", body, `data-show="E" data-key="5"`, `data-show="F" data-key="6"`, `data-show="D" data-key="d"`, "1 to 8")
	for _, taken := range []string{`data-key="e"`, `data-key="f"`} {
		if strings.Contains(body, taken) {
			t.Errorf("an option took the control key %s", taken)
		}
	}
	mustContain(t, "side", a.get("/r/m/1?view=side").Body.String(), "--n:4", `data-opt="F"`)
	mustContain(t, "phone", a.get("/r/m/1?phone=1").Body.String(), `class="row opts"`)
	if strings.Contains(a.get("/r/m/2?phone=1").Body.String(), `class="row opts"`) {
		t.Error("two options got their own phone row")
	}
}

func TestStepIntroStartsClosed(t *testing.T) {
	a := manyOptionsApp(t)
	intro := "Judge at 100 %; a neutral answer ships option A."
	for _, step := range []string{"/r/m/1", "/r/m/2"} {
		body := a.get(step).Body.String()
		mustContain(t, step, body, `<details class="intro"><summary>This round</summary>`, intro)
		if strings.Contains(body, `<section class="intro"`) {
			t.Errorf("%s shows the intro open", step)
		}
	}
	mustContain(t, "summary", a.get("/r/m/summary").Body.String(), `<section class="intro"`, intro)
	shipped := newShippedApp(t).locked()
	mustContain(t, "demo step 4", shipped.get("/r/demo/4?t="+roundToken("demo")).Body.String(), `<details class="intro">`, "Demo only: judge on any screen.")
}

func TestSideBySideKeepsTheRefTileBesideFourOptions(t *testing.T) {
	mustContain(t, "ref and four", manyOptionsApp(t).get("/r/m/3?view=side").Body.String(), "--n:5", "reft")
}

func TestBlindStepsShowNoMeasurementsBeforeThePick(t *testing.T) {
	a := newShippedApp(t)
	if strings.Contains(a.get("/r/demo/1").Body.String(), "data-measure") {
		t.Error("a blind step offers measurements before the pick")
	}
	wantStatus(t, a.post("/r/demo/pictures/pick", url.Values{"pick": {"A"}}), http.StatusSeeOther)
	for _, target := range []string{"/r/demo/1", "/r/demo/1?view=side"} {
		mustContain(t, target, a.get(target).Body.String(), `data-measure="A"`, `data-measure="C"`)
	}
}

func TestLargeButtonOnlyWhereThereIsAPicture(t *testing.T) {
	a := manyOptionsApp(t)
	mustContain(t, "pictures", a.get("/r/m/1").Body.String(), `data-act="large"`)
	if strings.Contains(a.get("/r/m/2").Body.String(), `data-act="large"`) {
		t.Error("a text step has a Large button")
	}
	mustContain(t, "gallery", newApp(t).get("/r/r/3").Body.String(), `data-act="large"`)
}

func TestEveryOptionHasAMeasureSlotAndTheDemoSceneReports(t *testing.T) {
	a := newShippedApp(t)
	for _, target := range []string{"/r/demo-controls/4", "/r/demo-controls/4?view=side"} {
		mustContain(t, target, a.get(target).Body.String(), `data-measure="A"`, `data-measure="B"`)
	}
	mustContain(t, "scene", a.get("/static/demo/scene.html").Body.String(), "type: 'wr:measure'", "parent.postMessage(", "'wr:ask-measure'")
	mustContain(t, "page script", a.get("/static/warroom.js").Body.String(), "type: 'wr:ask-measure'")
}

func TestHtmxLastPickSummaryShowsTheChangeCount(t *testing.T) {
	a := newApp(t)
	wantStatus(t, a.post("/r/r/gal/pick", url.Values{"pick": {"pass"}}), http.StatusSeeOther)
	rec := a.fragment(http.MethodPost, "/r/r/gal/pick", url.Values{"pick": {"changes"}})
	mustContain(t, "summary after the last pick", rec.Body.String(), "What the server recorded", "changed 2 times")
}

// choiceOf builds one step's choice view from a one-step round, with a root holding docs/a.txt.
func choiceOf(t *testing.T, stepYAML, rawQuery string) (*builder, ChoiceView) {
	t.Helper()
	c := rounds.LoadCatalog(writeTree(t, map[string]string{
		"index.yaml":   "- {id: x, title: X}\n",
		"x/round.yaml": "title: X\nsteps: [s]\n",
		"x/s.yaml":     stepYAML,
	}))
	if len(c.Errors) > 0 {
		t.Fatal(c.Errors)
	}
	root, err := os.OpenRoot(writeTree(t, map[string]string{"docs/a.txt": "doc"}))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = root.Close() })
	q, err := url.ParseQuery(rawQuery)
	if err != nil {
		t.Fatal(err)
	}
	b := &builder{cat: c, round: c.Rounds["x"], q: parseQuery(q), root: root}
	v := b.choice(1, &b.round.Loaded[0], "", "")
	return b, v
}

func TestMissingLocalExtraIsLeftOut(t *testing.T) {
	_, v := choiceOf(t, "kind: pictures\nquestion: Q\noptions:\n  A: {name: a, img: docs/a.txt, extra: [{label: mine, img: docs/nope.webp, local: true}, {label: lost, img: docs/lost.webp}]}\n", "")
	got := v.Opts[0].Extras
	if len(got) != 1 || got[0].Label != "lost" || got[0].Pic.Kind != "missing" {
		t.Errorf("extras %+v, want only the committed one, shown as missing", got)
	}
}

func TestRefFeedsTodayNotInfo(t *testing.T) {
	const step = "kind: pictures\nquestion: Q\nref: {label: Today, img: docs/a.txt}\noptions:\n  A: {name: a, img: docs/a.txt}\n  B: {name: b, img: docs/a.txt}\n"
	for _, q := range []string{"", "view=side"} {
		if _, v := choiceOf(t, step, q); v.Ref == nil || v.Info.Ref != nil {
			t.Errorf("%q: choice ref %v, info ref %v; want the ref on the Today row only", q, v.Ref, v.Info.Ref)
		}
	}
	b, _ := choiceOf(t, step, "")
	s := &b.round.Loaded[0]
	s.Kind = "verdict"
	if b.info(b.stage(s), s).Ref == nil {
		t.Error("a step kind without option rows lost its reference fold")
	}
}

func TestStatusListsOnlyViewValues(t *testing.T) {
	bar := CtlBarView{Buttons: []CtlButton{
		{Name: "size", Value: "1280 x 720"},
		{Name: "fit", Value: "Fit"},
		{Name: "world", Value: "n/a with a backdrop", Disabled: true},
		{Name: "numbers", Value: "shown"},
	}}
	if got := bar.Status(); got != "1280 x 720 · Fit" {
		t.Errorf("status %q, want only the view values", got)
	}
}
