//go:build browser

package web

import (
	"fmt"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/mxschmitt/playwright-go"
)

func TestFlipKeepsEveryFrameDocument(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.open(t, "/r/demo/10")
	s.wantCount(t, s.loc("iframe"), 6)
	s.markFrames(t)
	s.press(t, "a")
	s.press(t, "5")
	s.click(t, `.flipbar [data-show=B]`)
	s.wantClass(t, s.loc(`.flipbar [data-show=B]`), "on")
	s.wantFramesKept(t, 6)
}

func TestStageControlReloadsTheFramesWithTheNewHash(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.open(t, "/r/demo-controls/4")
	s.wantCount(t, s.loc("iframe"), 2)
	s.markFrames(t)
	s.press(t, "g")
	eventually(t, "frames reloaded with ground=dark", func() bool {
		scenes := s.sceneFrames()
		for _, f := range scenes {
			if !strings.Contains(f.URL(), "ground=dark") || frameValue(f, "window.__doc") != nil {
				return false
			}
		}
		return len(scenes) == 2
	})
}

func TestPickRecordsAndMovesOn(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.open(t, "/r/demo/1")
	s.press(t, "b")
	s.press(t, "Enter")
	s.wantURL(t, "/r/demo/2")
	if got := s.entries(t)["demo:pictures"]; got.Pick == nil || *got.Pick != "B" {
		t.Errorf("entry %+v, want pick B", got)
	}
}

func TestFailedPickShowsRetryAndRetryRecordsTheFailedLetter(t *testing.T) {
	for name, o := range map[string]struct{ secret, query string }{
		"open":       {},
		"with token": {testSecret, "?t=" + roundToken("demo")},
	} {
		t.Run(name, func(t *testing.T) {
			s := newSite(t, siteOpts{secret: o.secret})
			s.open(t, "/r/demo/1"+o.query)
			s.press(t, "b")
			s.failWrites.Store(true)
			s.press(t, "Enter")
			s.wantContains(t, s.loc("#rec .fail"), "Not recorded")
			s.wantClass(t, s.loc("#chips [data-step=pictures]"), "unsent")
			s.press(t, "a")
			s.failWrites.Store(false)
			s.click(t, "[data-retry]")
			s.wantText(t, s.loc("#rec"), "Recorded: pictures.")
			if got := s.entries(t)["demo:pictures"]; got.Pick == nil || *got.Pick != "B" {
				t.Errorf("entry %+v, want the failed pick B, not the shown A", got)
			}
		})
	}
}

func TestRetryNeverSendsANoteOlderThanARecordedOne(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.open(t, "/r/demo/1")
	s.press(t, "b")
	s.failWrites.Store(true)
	failIf(t, s.loc("#note").Fill("old"))
	s.wantContains(t, s.loc("#rec .fail"), "Not recorded")
	s.click(t, ".act [data-key=enter]")
	s.settle(t)
	s.failWrites.Store(false)
	s.click(t, `a[data-key=arrowright]`)
	s.wantURL(t, "/r/demo/2")
	s.click(t, `a[data-key=arrowleft]`)
	s.wantURL(t, "/r/demo/1")
	failIf(t, s.loc("#note").Fill("new"))
	eventually(t, "new note recorded", func() bool { return s.entries(t)["demo:pictures"].Note == "new" })
	s.click(t, "[data-retry]")
	s.wantContains(t, s.loc("#rec"), "Recorded: pictures.")
	if got := s.entries(t)["demo:pictures"]; got.Note != "new" || got.Pick == nil || *got.Pick != "B" {
		t.Errorf("entry %+v, want pick B with the newer note", got)
	}
}

func TestARecordedPickDropsAnOlderFailedNote(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.open(t, "/r/demo/1")
	s.failWrites.Store(true)
	failIf(t, s.loc("#note").Fill("old"))
	s.wantContains(t, s.loc("#rec .fail"), "Not recorded")
	s.failWrites.Store(false)
	// No input event, so only the pick carries the new text.
	eval(t, s.Page, `(() => { const n = document.querySelector('#note'); n.blur(); n.value = 'new'; })()`)
	s.click(t, ".act [data-key=enter]")
	s.wantURL(t, "/r/demo/2")
	s.settle(t)
	s.wantCount(t, s.loc("[data-retry]"), 0)
	if got := s.entries(t)["demo:pictures"].Note; got != "new" {
		t.Errorf("note %q, want new", got)
	}
}

func TestLeavingWithUnsentPicksAsksFirst(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.open(t, "/r/demo/1")
	s.failWrites.Store(true)
	s.press(t, "Enter")
	s.wantContains(t, s.loc("#rec .fail"), "Not recorded")
	var asked atomic.Bool
	s.Page.OnDialog(func(d playwright.Dialog) {
		asked.Store(d.Type() == "beforeunload")
		_ = d.Dismiss()
	})
	failIf(t, s.Page.Close(playwright.PageCloseOptions{RunBeforeUnload: playwright.Bool(true)}))
	eventually(t, "the leave warning", asked.Load)
}

func TestTabbingOntoAQuietPickShowsItsTile(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.open(t, "/r/demo/1?view=side")
	s.wantClass(t, s.loc(".tile[data-opt=A]"), "sel")
	failIf(t, s.loc(".tile[data-opt=B] > .pick").Focus())
	s.wantClass(t, s.loc(".tile[data-opt=B]"), "sel")
	s.press(t, "Enter")
	s.wantURL(t, "/r/demo/2")
	if got := s.entries(t)["demo:pictures"]; got.Pick == nil || *got.Pick != "B" {
		t.Errorf("entry %+v, want B", got)
	}
}

func TestNoteSurvivesLeavingTheStepAfterAFailure(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.open(t, "/r/demo/1")
	s.failWrites.Store(true)
	failIf(t, s.loc("#note").Fill("kept across steps"))
	s.wantContains(t, s.loc("#rec .fail"), "Not recorded")
	s.click(t, `a[data-key=arrowright]`)
	s.wantURL(t, "/r/demo/2")
	s.wantContains(t, s.loc("#rec .fail"), "pictures")
	s.wantClass(t, s.loc("#chips [data-step=pictures]"), "unsent")
	s.failWrites.Store(false)
	s.click(t, "[data-retry]")
	s.wantText(t, s.loc("#rec"), "Recorded: pictures.")
	if got := s.entries(t)["demo:pictures"].Note; got != "kept across steps" {
		t.Errorf("note %q", got)
	}
}

func TestPhoneViewSheetOpens(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.open(t, "/_phone")
	phone := s.Page.FrameLocator("iframe")
	s.wantHidden(t, phone.Locator(".sheet"))
	failIf(t, phone.Locator("[data-act=sheet]").Click())
	s.wantVisible(t, phone.Locator(".sheet"))
	failIf(t, expect.Locator(phone.Locator("[data-act=sheet]")).ToHaveAttribute("aria-expanded", "true"))
}

// phoneFrame opens src in the 390 px frame and returns that frame once it is the phone page.
func (s *site) phoneFrame(t *testing.T, src, ready string) playwright.Frame {
	t.Helper()
	s.open(t, "/_phone?src="+src)
	s.wantVisible(t, s.Page.FrameLocator("iframe").Locator(ready))
	for _, f := range s.Page.Frames() {
		if strings.Contains(f.URL(), "phone=1") {
			return f
		}
	}
	t.Fatal("no phone frame")
	return nil
}

func TestPhoneBarStaysAtTheBottomBelowTheNote(t *testing.T) {
	s := newSite(t, siteOpts{})
	phone := s.phoneFrame(t, "/r/demo/1", ".phone [data-act=sheet]")
	const check = `(() => {
		const end = document.documentElement.scrollHeight - innerHeight;
		if (end < 20) return 'page fits the window, nothing to scroll';
		scrollTo(0, end / 2);
		const mid = document.querySelector('#phone').getBoundingClientRect().bottom;
		scrollTo(0, end);
		const bar = document.querySelector('#phone').getBoundingClientRect();
		const note = document.querySelector('.notebox').getBoundingClientRect();
		// Within a pixel: Linux fonts give a fractional page height, and the furthest scroll is a whole pixel.
		const atEdge = (y) => Math.abs(y - innerHeight) < 1;
		return atEdge(mid) && atEdge(bar.bottom) && note.bottom <= bar.top ? '' : 'mid-scroll bar to ' + mid + ', note to ' + note.bottom + ', bar ' + bar.top + ' to ' + bar.bottom + ', window ' + innerHeight;
	})()`
	if gap := eval(t, phone, check); gap != "" {
		t.Errorf("sheet closed: %v", gap)
	}
	failIf(t, phone.Locator("[data-act=sheet]").Click())
	s.wantVisible(t, phone.Locator(".sheet"))
	if gap := eval(t, phone, check); gap != "" {
		t.Errorf("sheet open: %v", gap)
	}
}

func TestRoundListHasNoEmptyPhoneStrip(t *testing.T) {
	s := newSite(t, siteOpts{})
	phone := s.phoneFrame(t, "/", ".rounds")
	if got := eval(t, phone, `getComputedStyle(document.querySelector('#phone')).display`); got != "none" {
		t.Errorf("empty phone bar display %v, want none", got)
	}
}

func TestPhoneBarNeverCoversThePageEnd(t *testing.T) {
	s := newSite(t, siteOpts{})
	phone := s.phoneFrame(t, "/r/demo/10", ".phone .row.opts")
	// A taller bar without a resize event stands in for larger text.
	gap := eval(t, phone, `(() => {
		document.head.insertAdjacentHTML('beforeend', '<style>.phone .btn { min-height: 80px }</style>');
		scrollTo(0, document.documentElement.scrollHeight);
		const bar = document.querySelector('#phone').getBoundingClientRect();
		const end = Math.max(...[...document.querySelectorAll('#main *')].map((e) => e.getBoundingClientRect().bottom));
		return bar.top >= end && bar.bottom === innerHeight ? '' : 'page end ' + end + ', bar ' + bar.top + ' to ' + bar.bottom + ', window ' + innerHeight;
	})()`)
	if gap != "" {
		t.Errorf("phone bar covers the page or leaves the bottom: %v", gap)
	}
}

func TestTuneSliderRedrawsWithoutReloadAndRecordsTheValue(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.open(t, "/r/demo/9")
	s.wantVisible(t, s.loc("wr-tune .tp-rotv"))
	s.markFrames(t)
	s.typeInto(t, "wr-tune .tp-sldtxtv_t input", "2")
	scene := s.sceneFrames()[0]
	eventually(t, "scene redrawn with outline 2", func() bool { return frameValue(scene, "H.get('outline')") == "2" })
	if frameValue(scene, "window.__doc") == nil {
		t.Error("the scene reloaded instead of redrawing")
	}
	s.click(t, `.act [data-key=enter]`)
	s.wantURL(t, "/r/demo/10")
	got := s.entries(t)["demo:tune"]
	if got.Pick == nil || *got.Pick != "tuned" || got.Value["outline"] != 2.0 {
		t.Errorf("entry %+v, want tuned with outline 2", got)
	}
}

func TestReadOnlyLinkHasNoPickControls(t *testing.T) {
	s := newSite(t, siteOpts{secret: testSecret})
	var posts int
	s.Page.OnRequest(func(r playwright.Request) {
		if r.Method() == "POST" {
			posts++
		}
	})
	s.open(t, "/r/demo/1")
	s.wantContains(t, s.loc("body"), "Read only")
	for _, sel := range []string{`[name=pick]`, `#answer`, `[data-key=enter]`, `#note`} {
		s.wantCount(t, s.loc(sel), 0)
	}
	s.press(t, "b")
	s.press(t, "Enter")
	s.settle(t)
	s.wantURL(t, "/r/demo/1?show=B")
	if posts != 0 || len(s.entries(t)) != 0 {
		t.Errorf("read-only page posted %d times, recorded %v", posts, s.entries(t))
	}
	s.open(t, "/r/demo/1?t="+roundToken("demo"))
	s.wantVisible(t, s.loc(`[data-key=enter]`))
}

func TestHeldEnterRecordsOnePick(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.open(t, "/r/demo/1")
	kb := s.Page.Keyboard()
	failIf(t, kb.Down("Enter"))
	s.wantURL(t, "/r/demo/2")
	for range 3 {
		failIf(t, kb.Down("Enter"))
	}
	failIf(t, kb.Up("Enter"))
	s.settle(t)
	if got := s.entries(t); len(got) != 1 {
		t.Errorf("a held Enter recorded %v, want only the first step", got)
	}
}

const keyRound = "kind: pictures\nquestion: Q\ncontrols: {fit: true}\nrender: {page: static/demo/scene.html, w: 1280, h: 720, hash: shot=1}\noptions:\n" +
	"  A: {name: One, render: {params: {outline: 0}}}\n  B: {name: Two, render: {params: {outline: 1}}}\n  C: {name: Three, render: {params: {outline: 2}}}\n" +
	"  D: {name: Four, render: {params: {outline: 3}}}\n  E: {name: Five, render: {params: {outline: 4}}}\n  F: {name: Six, render: {params: {outline: 5}}}\n"

func newKeySite(t *testing.T) *site {
	t.Helper()
	dir := writeTree(t, map[string]string{
		"index.yaml":   "- {id: k, title: Keys}\n",
		"k/round.yaml": "title: Keys\nsteps: [six]\n",
		"k/six.yaml":   keyRound,
	})
	s := newSite(t, siteOpts{rounds: dir})
	s.open(t, "/r/k/1")
	return s
}

func TestDigitFiveShowsOptionE(t *testing.T) {
	s := newKeySite(t)
	s.press(t, "5")
	s.wantVisible(t, s.loc(`.ostage[data-opt=E]`))
	s.wantClass(t, s.loc(`.flipbar [data-show=E]`), "on")
}

func TestLetterFStillToggleFitAndNamesItsDigit(t *testing.T) {
	s := newKeySite(t)
	s.press(t, "f")
	s.wantText(t, s.loc("#toast"), "Option F is key 6")
	s.wantClass(t, s.loc("#view"), "true100")
}

func TestLetterEOnlyNamesItsDigit(t *testing.T) {
	s := newKeySite(t)
	s.press(t, "b")
	s.press(t, "e")
	s.wantText(t, s.loc("#toast"), "Option E is key 5")
	s.wantVisible(t, s.loc(`.ostage[data-opt=B]`))
	s.wantHidden(t, s.loc(`.ostage[data-opt=E]`))
}

func TestMeasureFromAForeignOriginOrANonFrameIsIgnored(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.open(t, "/r/demo/10")
	s.wantVisible(t, s.loc(`[data-measure=C] table`))
	// localhost is another origin than 127.0.0.1, so this frame is on the page but foreign.
	eval(t, s.Page, `(() => {
		const f = document.createElement('iframe');
		f.id = 'foreign';
		f.src = location.href.replace('127.0.0.1', 'localhost').replace(/\/r\/.*/, '/static/demo/scene.html#shot=1');
		document.querySelector('.ostage:not([hidden]) .sc').append(f);
	})()`)
	var foreign playwright.Frame
	eventually(t, "the foreign frame", func() bool {
		for _, f := range s.Page.Frames() {
			if strings.Contains(f.URL(), "localhost") {
				foreign = f
			}
		}
		return foreign != nil
	})
	eval(t, foreign, `parent.postMessage({type: 'wr:measure', rows: [['evil', 'foreign origin']]}, '*')`)
	eval(t, s.Page, `postMessage({type: 'wr:measure', rows: [['evil', 'not a frame']]}, location.origin)`)
	s.settle(t)
	s.wantAbsent(t, s.loc(".measures"), "evil")
	s.wantHidden(t, s.loc("#flash"))
}

func TestMeasureRowsAreText(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.open(t, "/r/demo/10")
	s.wantVisible(t, s.loc(`[data-measure=C] table`))
	eval(t, s.frameEnding(t, "outline=1"), `parent.postMessage({type: 'wr:measure', rows: [['k', '<b>x</b>']]}, location.origin)`)
	s.wantText(t, s.loc(`[data-measure=C] td`), "<b>x</b>")
	s.wantCount(t, s.loc(`.measures b`), 0)
}

func TestScriptErrorsShowTheBanner(t *testing.T) {
	const reload = " — reload the page; picks may not record"
	for name, script := range map[string]string{
		"a thrown error":         `setTimeout(() => { throw new Error('boom') })`,
		"an unhandled rejection": `setTimeout(() => Promise.reject(new Error('nope')))`,
	} {
		t.Run(name, func(t *testing.T) {
			s := newSite(t, siteOpts{})
			s.open(t, "/r/demo/1")
			s.wantHidden(t, s.loc("#flash"))
			eval(t, s.Page, script)
			s.wantContains(t, s.loc("#flash"), "Page script error:")
			s.wantContains(t, s.loc("#flash"), reload)
		})
	}
}

func TestEarlyMeasureStillGetsItsTable(t *testing.T) {
	s := newSite(t, siteOpts{})
	// The frames report as soon as they load; the page script arrives long after, so only the ask brings the rows.
	failIf(t, s.Page.Route("**/static/warroom.js", func(r playwright.Route) {
		time.Sleep(800 * time.Millisecond)
		_ = r.Continue()
	}))
	s.open(t, "/r/demo/10")
	s.wantContains(t, s.loc(`[data-measure=C] table`), "Units drawn")
}

func TestMeasureTableSurvivesAControlThatKeepsTheFrame(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.open(t, "/r/demo-controls/4")
	table := s.loc(`.measure table`)
	s.wantContains(t, table.First(), "Units drawn")
	s.markFrames(t)
	s.press(t, "f")
	s.wantClass(t, s.loc("#view"), "true100")
	s.wantFramesKept(t, 2)
	s.wantContains(t, table.First(), "Units drawn")
}

func TestMeasureTableIsUnderItsOptionInFlipAndSideViews(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.open(t, "/r/demo/10")
	s.wantContains(t, s.loc(`[data-measure=C]`), "1 px")
	for key, want := range map[string]string{"a": "0 px", "5": "2 px", "d": "1.5 px"} {
		s.press(t, key)
		letter := strings.ToUpper(map[string]string{"a": "a", "5": "e", "d": "d"}[key])
		s.wantContains(t, s.loc(`[data-measure=`+letter+`]`), want)
		s.wantCount(t, s.loc(`.measure:visible`), 1)
	}
	s.open(t, "/r/demo/10?view=side")
	s.wantContains(t, s.loc(`.tile[data-opt=B] .measure`), "0.5 px")
	s.wantContains(t, s.loc(`.tile[data-opt=D] .measure`), "1.5 px")
}

func TestLargeButtonOpensTheLargeView(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.open(t, "/r/demo/1")
	s.wantHidden(t, s.loc("#over"))
	s.click(t, "[data-act=large]")
	s.wantVisible(t, s.loc("#over .ov"))
	s.press(t, "Escape")
	s.wantHidden(t, s.loc("#over"))
}

func TestTuneElementLeavesNoOrphanPaneWhenReconnected(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.open(t, "/r/demo/9")
	s.wantVisible(t, s.loc("wr-tune .tp-rotv"))
	got := eval(t, s.Page, `(async () => {
		const tune = document.querySelector('wr-tune'), host = tune.parentNode;
		const tick = () => new Promise((r) => setTimeout(r, 50));
		for (let i = 0; i < 2; i++) { tune.remove(); await tick(); host.append(tune); await tick(); }
		const connected = tune.querySelectorAll('.tp-rotv').length;
		tune.remove(); await tick();
		return [connected, document.querySelectorAll('.tp-rotv').length, tune.querySelectorAll('.tp-rotv').length];
	})()`)
	if fmt.Sprint(got) != "[1 0 0]" {
		t.Errorf("panes (connected, in document after removal, left in the element) = %v, want [1 0 0]", got)
	}
}
