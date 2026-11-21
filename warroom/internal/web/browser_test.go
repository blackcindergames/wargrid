//go:build browser

package web

import (
	"encoding/base64"
	"fmt"
	"regexp"
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
	s.click(t, `.orow[data-show=B]`)
	s.wantClass(t, s.loc(`.orow[data-show=B]`), "sel")
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
		// Within a pixel: a fractional page height leaves the furthest scroll short of it, as in the test above.
		return bar.top >= end && Math.abs(bar.bottom - innerHeight) < 1 ? '' : 'page end ' + end + ', bar ' + bar.top + ' to ' + bar.bottom + ', window ' + innerHeight;
	})()`)
	if gap != "" {
		t.Errorf("phone bar covers the page or leaves the bottom: %v", gap)
	}
}

var phoneSteps = []string{"/r/p2-3b-dock/1", "/r/p2-3b-dock/5"}

func TestPhoneStepLayout(t *testing.T) {
	s := newSite(t, siteOpts{})
	var heights []any
	for _, step := range phoneSteps {
		phone := s.phoneFrame(t, step, ".zone")
		if got := eval(t, phone, `(() => { const d = document.documentElement; return d.scrollWidth <= d.clientWidth ? '' : d.scrollWidth + ' > ' + d.clientWidth; })()`); got != "" {
			t.Errorf("%s scrolls sideways: %v", step, got)
		}
		got := eval(t, phone, `(() => {
			scrollTo(0, 0);
			const r = (sel) => document.querySelector(sel).getBoundingClientRect();
			const q = r('.head h1'), look = r('.look'), pick = r('.phone .pick'), bar = r('#phone');
			const bad = [];
			if (q.top < 0 || q.bottom > bar.top) bad.push('question ' + q.top + ' to ' + q.bottom);
			if (look.bottom > bar.top) bad.push('look ends ' + look.bottom);
			if (pick.top < bar.top || pick.bottom > innerHeight) bad.push('pick ' + pick.top + ' to ' + pick.bottom);
			if (Math.abs(bar.bottom - innerHeight) >= 1) bad.push('bar ends ' + bar.bottom + ' in a window of ' + innerHeight);
			return bad.join(', ') + (bad.length ? ', bar top ' + bar.top : '');
		})()`)
		if got != "" {
			t.Errorf("%s at the top: %v", step, got)
		}
		if got := eval(t, phone, `(() => {
			const z = document.querySelector('.zone').getBoundingClientRect(), page = document.documentElement.clientWidth;
			return Math.abs(z.height - z.width * 3 / 4) <= 1 && z.width >= page - 32 - 1 ? '' : z.width + ' x ' + z.height + ' in a page ' + page + ' wide';
		})()`); got != "" {
			t.Errorf("%s stage %v, want 4:3 at full width less the 16 px gutters", step, got)
		}
		heights = append(heights, eval(t, phone, `String(document.querySelector('.zone').getBoundingClientRect().height)`))
	}
	if heights[0] != heights[1] {
		t.Errorf("stage heights %v, want the same on both steps", heights)
	}
}

func TestPhonePickWearsClaudesTab(t *testing.T) {
	s := newSite(t, siteOpts{})
	// Claude's pick on this step is A, and the step opens on A.
	phone := s.phoneFrame(t, "/r/p2-3b-dock/1", ".phone .pick")
	tab := phone.Locator(".phone .pick .ptab")
	s.wantVisible(t, tab)
	width := `document.querySelector('.phone .pick').getBoundingClientRect().width`
	with := eval(t, phone, width)
	got := eval(t, phone, `(() => {
		const r = (e) => e.getBoundingClientRect();
		const tab = r(document.querySelector('.phone .ptab')), pick = r(document.querySelector('.phone .pick')), bar = r(document.querySelector('#phone'));
		const hit = [...document.querySelectorAll('.phone .btn:not(.pick)')].map(r).some((b) => b.width && tab.left < b.right && tab.right > b.left && tab.top < b.bottom && tab.bottom > b.top);
		const ok = Math.abs(tab.bottom - pick.top) < 2 && Math.abs(tab.left - pick.left) < 2 && tab.top >= bar.top && tab.right <= innerWidth && !hit;
		return ok ? '' : 'tab ' + tab.left + ',' + tab.top + ' to ' + tab.right + ',' + tab.bottom + '; pick ' + pick.left + ',' + pick.top + '; bar top ' + bar.top + '; covers a button ' + hit;
	})()`)
	if got != "" {
		t.Errorf("tab not on Pick's top edge inside the bar: %v", got)
	}
	failIf(t, phone.Locator(".phone .ob[data-show=B]").Click())
	s.wantHidden(t, tab)
	s.wantContains(t, phone.Locator(".phone .pick"), "Pick B")
	if without := eval(t, phone, width); without != with {
		t.Errorf("phone Pick width %v with the tab, %v without", with, without)
	}
	failIf(t, phone.Locator(".phone .ob[data-show=A]").Click())
	s.wantVisible(t, tab)
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
	s.wantText(t, s.loc("#readonly"), "View only: you can look around, nothing you do is recorded")
	if n, err := s.loc(".opts .orow").Count(); err != nil || n == 0 {
		t.Errorf("read-only page has %d option rows (%v), want the rows without pick controls", n, err)
	}
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
	// Step 10 is not blind and opens on Claude's option with show=C, so only the read-only rule keeps the tab off.
	s.open(t, "/r/demo/10?show=C")
	s.wantVisible(t, s.loc(".orow[data-show=C]"))
	for _, sel := range []string{`.ptab`, `.tag.cp`, `.rpanel [name=pick]`, `.rpanel [data-note]`, `[value=neither]`} {
		s.wantCount(t, s.loc(sel), 0)
	}
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
	s.wantClass(t, s.loc(`.orow[data-show=E]`), "sel")
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
	s.open(t, "/r/demo/10?show=C")
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
	s.open(t, "/r/demo/10?show=C")
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
	s.wantContains(t, s.loc(`.cpanel .measures [data-measure=C]`), "1 px")
	for key, want := range map[string]string{"a": "0 px", "5": "2 px", "d": "1.5 px"} {
		s.press(t, key)
		letter := strings.ToUpper(map[string]string{"a": "a", "5": "e", "d": "d"}[key])
		s.wantContains(t, s.loc(`.cpanel .measures [data-measure=`+letter+`]`), want)
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

// Token values as Firefox reports them: --text, --muted, --amber, --quiet, --well, --slab, --sel.
const (
	textRGB  = "rgb(223, 231, 236)"
	mutedRGB = "rgb(147, 165, 176)"
	amberRGB = "rgb(247, 200, 113)"
	wellRGB  = "rgb(12, 20, 26)"
	slabRGB  = "rgb(18, 28, 36)"
	selRGB   = "rgb(96, 229, 237)"
	quietRGB = "rgb(22, 33, 42)"
)

// cssOf reads one computed property of the first element matching sel, or of its pseudo element.
func cssOf(t *testing.T, e interface {
	Evaluate(string, ...any) (any, error)
}, sel, pseudo, prop string,
) any {
	t.Helper()
	return eval(t, e, fmt.Sprintf(`getComputedStyle(document.querySelector(%q), %q).getPropertyValue(%q)`, sel, pseudo, prop))
}

func TestNonBlindStepOpensOnANotOnClaudesPick(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.open(t, "/r/demo/10")
	s.wantClass(t, s.loc(`.orow[data-show=A]`), "sel")
	s.wantVisible(t, s.loc(`.ostage[data-opt=A]`))
	failIf(t, expect.Locator(s.loc(".act .ptab")).ToHaveAttribute("data-cp", "C"))
	s.wantHidden(t, s.loc(".act .ptab"))
	s.press(t, "b")
	s.press(t, "Enter")
	s.wantURL(t, "/r/demo/summary")
	s.open(t, "/r/demo/10")
	s.wantClass(t, s.loc(`.orow[data-show=B]`), "sel")
}

// badgeCheck lists what is wrong with every Claude's-pick tag matching sel: colours, case, contrast.
const badgeCheck = `([sel, fg, bg]) => {
	const lum = (c) => {
		const v = c.match(/\d+/g).slice(0, 3).map((x) => { x /= 255; return x <= 0.04045 ? x / 12.92 : ((x + 0.055) / 1.055) ** 2.4; });
		return 0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2];
	};
	const tags = [...document.querySelectorAll(sel)];
	if (!tags.length) return 'none found';
	return tags.map((e) => {
		const c = getComputedStyle(e);
		const [hi, lo] = [lum(c.backgroundColor), lum(c.color)].sort((a, b) => b - a);
		const ratio = (hi + 0.05) / (lo + 0.05);
		const bad = [];
		if (c.backgroundColor !== bg || c.color !== fg) bad.push('colours ' + c.color + ' on ' + c.backgroundColor);
		if (c.textTransform !== 'none' || e.textContent !== "Claude's pick") bad.push('text ' + c.textTransform + ' ' + e.textContent);
		if (ratio < 7) bad.push('contrast ' + ratio.toFixed(1));
		return bad.join(', ');
	}).filter(Boolean).join('; ');
}`

func TestClaudesPickIsALightBadge(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.open(t, "/r/demo/10?show=C")
	got, err := s.Page.Evaluate(badgeCheck, []any{".act .ptab", wellRGB, textRGB})
	failIf(t, err)
	if got != "" {
		t.Errorf("Pick's tab: %v", got)
	}
	s.wantCount(t, s.loc(".pic .tag"), 0)
}

func TestBlindStepHasNoBadgeBeforeThePick(t *testing.T) {
	s := newSite(t, siteOpts{})
	for _, path := range []string{"/r/demo/1", "/r/demo/1?view=side", "/r/demo/1?show=B"} {
		s.open(t, path)
		s.wantCount(t, s.loc(".opts .orow"), 3)
		s.wantCount(t, s.loc(".orow .tag"), 0)
		s.wantCount(t, s.loc(".tag.cp, .ptab"), 0)
	}
}

func TestPhoneSideAndNeutralLiveInTheControlsSheet(t *testing.T) {
	s := newSite(t, siteOpts{})
	// The demo step with the most stage controls that has a neutral answer.
	phone := s.phoneFrame(t, "/r/demo-controls/1", ".phone [data-act=sheet]")
	bar := phone.Locator(".phone .row")
	s.wantCount(t, bar.Locator("[value=neither]"), 0)
	s.wantCount(t, bar.Locator("[data-keepview]"), 0)
	s.wantText(t, phone.Locator("[data-act=sheet]"), "Controls")
	failIf(t, phone.Locator("[data-act=sheet]").Click())
	s.wantText(t, phone.Locator(".sheet > .ctlbar:first-child > a"), "Side")
	neutral := phone.Locator(".sheet [value=neither]")
	failIf(t, expect.Locator(neutral).ToBeInViewport(playwright.LocatorAssertionsToBeInViewportOptions{Ratio: playwright.Float(1)}))
	edge, err := neutral.Evaluate(`(e) => getComputedStyle(e).borderTopColor`, nil)
	failIf(t, err)
	if edge != mutedRGB {
		t.Errorf("sheet neutral edge %v, want --muted %s", edge, mutedRGB)
	}
	failIf(t, neutral.Click())
	eventually(t, "the neutral answer recorded", func() bool {
		got := s.entries(t)["demo-controls:hud-window"]
		return got.Pick != nil && *got.Pick == "neither"
	})
}

func TestTuneSliderKnobIsTextOnAMutedTrack(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.open(t, "/r/demo/9")
	s.wantVisible(t, s.loc("wr-tune .tp-sldv_k").First())
	knob := cssOf(t, s.Page, "wr-tune .tp-sldv_k", "::after", "background-color")
	track := cssOf(t, s.Page, "wr-tune .tp-sldv_t", "::before", "background-color")
	if knob != textRGB || track != mutedRGB {
		t.Errorf("knob %v, track %v; want --text %s on --muted %s", knob, track, textRGB, mutedRGB)
	}
}

func TestTuneSliderShowsKeyboardFocus(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.open(t, "/r/demo/9")
	failIf(t, s.loc("wr-tune .tp-sldtxtv_t input").First().Click())
	s.press(t, "Shift+Tab")
	got := eval(t, s.Page, `(() => {
		const e = document.activeElement, c = getComputedStyle(e);
		return [e.className, c.outlineStyle, c.outlineWidth, c.outlineColor].join(' | ');
	})()`)
	if want := "tp-sldv_t | solid | 2px | " + textRGB; got != want {
		t.Errorf("focused slider (class | outline) = %v, want %v", got, want)
	}
}

func TestSideViewClickingATileSelectsItAndThePickFollows(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.open(t, "/r/demo/10?view=side")
	s.wantCount(t, s.loc(".tile .pick"), 0)
	pick := s.loc(".rpanel .pick")
	s.wantText(t, pick.Locator(".pl"), "A")
	// The tile's padding, away from its header and picture.
	failIf(t, s.loc(".tile[data-opt=B]").Click(playwright.LocatorClickOptions{Position: &playwright.Position{X: 5, Y: 5}}))
	s.wantClass(t, s.loc(".tile[data-opt=B]"), "sel")
	s.wantText(t, pick.Locator(".pl"), "B")
	s.press(t, "c")
	s.wantText(t, pick.Locator(".pl"), "C")
	s.press(t, "b")
	s.press(t, "Enter")
	s.wantURL(t, "/r/demo/summary")
	if got := s.entries(t)["demo:many"]; got.Pick == nil || *got.Pick != "B" {
		t.Errorf("entry %+v, want B", got)
	}
}

func TestSideViewSharesThePickInTheRightPanel(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.open(t, "/r/demo/10")
	flip := s.rect(t, ".rpanel button.pick")
	s.open(t, "/r/demo/10?view=side")
	s.wantVisible(t, s.loc(".rpanel .act .pick + [value=neither]"))
	s.wantCount(t, s.loc(".cpanel .act"), 0)
	if side := s.rect(t, ".rpanel button.pick"); !near(side, flip) {
		t.Errorf("Pick at %+v side by side, %+v one at a time", side, flip)
	}
	colours := fmt.Sprint(cssOf(t, s.Page, ".rpanel .act .pick", "", "background-color"), " ",
		cssOf(t, s.Page, ".rpanel .act [value=neither]", "", "background-color"), " ",
		cssOf(t, s.Page, ".rpanel .act [value=neither]", "", "border-top-color"))
	if want := amberRGB + " " + quietRGB + " " + mutedRGB; colours != want {
		t.Errorf("Pick fill, neutral fill, neutral edge = %s, want %s", colours, want)
	}
}

// stackCheck says what is wrong with the right panel's order under the list: Pick, neutral, note, nav, each at most 16 px below the one before.
const stackCheck = `() => {
	const parts = ['.opts', '.act .pick', '.act [value=neither]', '.notebox', '.stepnav'];
	const r = parts.map((sel) => document.querySelector('.rpanel ' + sel).getBoundingClientRect());
	const gaps = r.slice(1).map((x, i) => Math.round(x.top - r[i].bottom));
	const ok = gaps.every((g) => g >= 0 && g <= 16) && r[1].height === 44;
	return ok ? '' : 'gaps ' + gaps.join(' ') + ' between ' + parts.join(', ') + '; Pick height ' + r[1].height;
}`

func TestPickNeutralNoteAndNavFollowTheListWithNoSpacer(t *testing.T) {
	s := newSite(t, siteOpts{})
	for _, path := range []string{"/r/demo/10", "/r/demo/10?view=side", "/r/p2-3b-dock/5"} {
		s.open(t, path)
		if got := eval(t, s.Page, stackCheck); got != "" {
			t.Errorf("%s: %v", path, got)
		}
	}
}

func TestTunePaneRowsHaveOneEvenGapAndTheRingStaysInItsRow(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.open(t, "/r/demo/9")
	s.wantVisible(t, s.loc("wr-tune .tp-rotv").First())
	gaps := eval(t, s.Page, `(() => {
		const rows = [...document.querySelectorAll('wr-tune .tp-rotv_c > *')].map((e) => e.getBoundingClientRect());
		return [...new Set(rows.slice(1).map((r, i) => Math.round(r.top - rows[i].bottom)))].join(' ');
	})()`)
	if gaps != "8" {
		t.Errorf("gaps between tune rows %v, want one gap of 8 px", gaps)
	}
	failIf(t, s.loc("wr-tune .tp-sldtxtv_t input").First().Click())
	s.press(t, "Shift+Tab")
	ring := eval(t, s.Page, `(() => {
		const t = document.activeElement, c = getComputedStyle(t);
		const grow = parseFloat(c.outlineWidth) + parseFloat(c.outlineOffset), r = t.getBoundingClientRect();
		const ring = { l: r.left - grow, t: r.top - grow, r: r.right + grow, b: r.bottom + grow };
		const row = t.closest('.tp-lblv').getBoundingClientRect(), box = t.closest('.tp-lblv').querySelector('.tp-sldtxtv_t').getBoundingClientRect();
		const inRow = ring.t >= row.top && ring.b <= row.bottom && ring.l >= row.left;
		const clear = ring.r < box.left;
		return inRow && clear ? '' : 'ring ' + JSON.stringify(ring) + ', row ' + row.top + ' to ' + row.bottom + ', value box from ' + box.left;
	})()`)
	if ring != "" {
		t.Errorf("focus ring leaves its row or touches the value box: %v", ring)
	}
}

func TestSideViewPictureClickSelectsFirstThenOpensLarge(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.open(t, "/r/demo/10?view=side")
	s.click(t, ".tile[data-opt=B] .pic")
	s.wantClass(t, s.loc(".tile[data-opt=B]"), "sel")
	s.settle(t)
	s.wantHidden(t, s.loc("#over"))
	s.click(t, ".tile[data-opt=B] .pic")
	s.wantVisible(t, s.loc("#over .ov"))
}

func TestSideViewSelectionShowsInTheLetterAndThePick(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.open(t, "/r/demo/10?view=side")
	pick := s.loc(".rpanel .pick")
	s.wantCount(t, pick.Locator(".pn"), 0)
	width := `document.querySelector('.rpanel .pick').offsetWidth`
	wantWidth := eval(t, s.Page, width)
	if c := cssOf(t, s.Page, ".tile.sel .let", "", "color"); c != selRGB {
		t.Errorf("selected letter %v, want --sel %s", c, selRGB)
	}
	if c := cssOf(t, s.Page, ".tile:not(.sel) .let", "", "color"); c == selRGB {
		t.Error("an unselected letter is --sel too")
	}
	s.click(t, ".tile[data-opt=B] .ohd")
	s.wantText(t, pick.Locator(".pl"), "B")
	eval(t, s.Page, `document.querySelector('.tile[data-opt=C] .ohd h2').textContent = 'A very long option name '.repeat(20)`)
	s.press(t, "c")
	s.wantText(t, pick.Locator(".pl"), "C")
	// The owner asked for a Pick that never changes width between options (2026-11-21).
	if got := eval(t, s.Page, width); got != wantWidth {
		t.Errorf("Pick width %v on C, want %v as on A", got, wantWidth)
	}
}

func TestSideViewPlayOnAnotherTileSelectsIt(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.open(t, "/r/demo/4")
	s.wantClass(t, s.loc(".tile[data-opt=A]"), "sel")
	s.click(t, ".tile[data-opt=B] [data-play]")
	s.wantClass(t, s.loc(".tile[data-opt=B]"), "sel")
	s.wantText(t, s.loc(".rpanel .pick .pl"), "B")
}

// recordClip makes a short VP8 WebM in the browser, since the repository tracks no video.
func recordClip(t *testing.T, s *site) []byte {
	t.Helper()
	s.open(t, "/")
	b64 := eval(t, s.Page, `(async () => {
		const c = Object.assign(document.createElement('canvas'), { width: 64, height: 36 });
		const g = c.getContext('2d');
		const rec = new MediaRecorder(c.captureStream(25), { mimeType: 'video/webm;codecs=vp8' });
		const parts = [];
		rec.ondataavailable = (e) => parts.push(e.data);
		const done = new Promise((r) => { rec.onstop = r; });
		rec.start();
		for (let i = 0; i < 30; i++) {
			g.fillStyle = 'hsl(' + i * 12 + ' 80% 50%)';
			g.fillRect(0, 0, 64, 36);
			await new Promise((r) => setTimeout(r, 40));
		}
		rec.stop();
		await done;
		let out = '';
		for (const x of new Uint8Array(await new Blob(parts).arrayBuffer())) out += String.fromCharCode(x);
		return btoa(out);
	})()`)
	data, err := base64.StdEncoding.DecodeString(fmt.Sprint(b64))
	failIf(t, err)
	return data
}

func TestSideViewClickOnAnotherTilesClipSelectsItAndKeepsItPlaying(t *testing.T) {
	clip := string(recordClip(t, newSite(t, siteOpts{})))
	root := writeTree(t, map[string]string{"docs/a.webm": clip, "docs/b.webm": clip})
	dir := writeTree(t, map[string]string{
		"index.yaml":   "- {id: v, title: Clips}\n",
		"v/round.yaml": "title: Clips\nsteps: [clips]\n",
		"v/clips.yaml": "kind: pictures\nquestion: Q\nview: side\noptions:\n  A: {name: One, video: docs/a.webm}\n  B: {name: Two, video: docs/b.webm}\n",
	})
	s := newSite(t, siteOpts{rounds: dir, root: root})
	s.open(t, "/r/v/1")
	s.wantClass(t, s.loc(".tile[data-opt=A]"), "sel")
	s.click(t, ".tile[data-opt=B] video")
	s.wantClass(t, s.loc(".tile[data-opt=B]"), "sel")
	s.settle(t)
	if paused := eval(t, s.Page, `document.querySelector('.tile[data-opt=B] video').paused`); paused != false {
		t.Errorf("B's clip paused = %v after the click that selected it, want playing", paused)
	}
}

func TestCookieCarriesRequestsWithoutTheQuery(t *testing.T) {
	s := newSite(t, siteOpts{secret: testSecret})
	if err := s.Page.Context().ClearCookies(); err != nil {
		t.Fatal(err)
	}
	s.open(t, "/r/demo/1?t="+viewerToken)
	const probe = `(async () => {
		const img = document.querySelector('#stage img, img');
		const status = async (u, h) => (await fetch(u, {headers: h || {}})).status;
		return {
			img: img ? img.getAttribute('src') : '',
			imgStatus: img ? await status(img.src) : 0,
			css: await status('/static/app.css'),
			step: await status('/r/demo/2', {'HX-Request': 'true'}),
			script: document.cookie.includes('wr='),
		};
	})()`
	got := eval(t, s.Page, probe).(map[string]any)
	if src, _ := got["img"].(string); src == "" || strings.Contains(src, "t=") {
		t.Fatalf("picture src %q: want one without the token", src)
	}
	for _, k := range []string{"imgStatus", "css", "step"} {
		if got[k] != 200 {
			t.Errorf("%s: status %v, want 200 by the cookie", k, got[k])
		}
	}
	if got["script"] != false {
		t.Error("page script can read the wr cookie; want HttpOnly")
	}
	if err := s.Page.Context().ClearCookies(); err != nil {
		t.Fatal(err)
	}
	refused := eval(t, s.Page, `fetch('/r/demo/2', {headers: {'HX-Request': 'true'}}).then(async r => r.status + ' ' + await r.text())`)
	if refused != "403 "+gateText {
		t.Errorf("without the cookie: %q, want 403 %q", refused, gateText)
	}
}

const todayRound = "kind: pictures\nquestion: Q\nwhy: W\nrec: B\nrecWhy: because\ncontrols: {fit: true}\nrender: {page: static/demo/scene.html, w: 1280, h: 720, hash: shot=1}\n" +
	"ref: {label: 'Today: as built', render: {params: {outline: 3}}}\noptions:\n" +
	"  A: {name: One, notes: first, sees: a look, render: {params: {outline: 0}}, extra: [{label: More A, render: {params: {outline: 4}}}]}\n" +
	"  B: {name: Two, notes: second, sees: b look, render: {params: {outline: 1}}, extra: [{label: More B, render: {params: {outline: 5}}}]}\n" +
	"  C: {name: Three, render: {params: {outline: 2}}}\n"

// newTodaySite serves one step with a Today picture, extras on A and B, and Claude's pick on B.
func newTodaySite(t *testing.T) *site {
	t.Helper()
	dir := writeTree(t, map[string]string{
		"index.yaml":   "- {id: d, title: Today}\n",
		"d/round.yaml": "title: Today\nintro: The round.\nsteps: [ref]\n",
		"d/ref.yaml":   todayRound,
	})
	s := newSite(t, siteOpts{rounds: dir})
	s.open(t, "/r/d/1")
	return s
}

func TestKeyZeroShowsTodayAndDisablesPick(t *testing.T) {
	s := newTodaySite(t)
	pick := s.loc(".rpanel button.pick")
	s.press(t, "0")
	s.wantVisible(t, s.loc(`.ostage[data-opt=today]`))
	s.wantHidden(t, s.loc(`.ostage[data-opt=A]`))
	failIf(t, expect.Locator(pick).ToBeDisabled())
	s.press(t, "Enter")
	s.settle(t)
	if got := s.entries(t); len(got) != 0 {
		t.Errorf("Enter on Today recorded %v, want nothing", got)
	}
	s.press(t, "b")
	failIf(t, expect.Locator(pick).ToBeEnabled())
	s.wantContains(t, pick, "Pick B")
	s.click(t, `.opts .orow[data-show=today]`)
	s.wantVisible(t, s.loc(`.ostage[data-opt=today]`))
	failIf(t, expect.Locator(pick).ToBeDisabled())
	s.press(t, "Enter")
	s.settle(t)
	if got := s.entries(t); len(got) != 0 {
		t.Errorf("Enter after a click on the Today row recorded %v, want nothing", got)
	}
}

func TestSideViewHasNoTodayRowAndZeroDoesNothing(t *testing.T) {
	s := newTodaySite(t)
	s.open(t, "/r/d/1?view=side")
	s.wantVisible(t, s.loc(".tile.reft"))
	s.wantCount(t, s.loc(".orow[data-show=today]"), 0)
	s.press(t, "0")
	s.settle(t)
	failIf(t, expect.Locator(s.loc(".rpanel button.pick")).ToBeEnabled())
	s.wantClass(t, s.loc(".tile[data-opt=A]"), "sel")
	if got := eval(t, s.Page, `[...document.querySelectorAll('.opts .orow')].map((r) => r.dataset.show).join(' ')`); got != "A B C" {
		t.Errorf("side view rows %v, want A B C", got)
	}
}

// A note the row shows whole is never repeated, and a fold with nothing else to say stays out of sight.
func TestAboutFoldNeverRepeatsTheNotes(t *testing.T) {
	s := newTodaySite(t)
	s.wantContains(t, s.loc(".about[data-opt=A]"), "a look")
	s.click(t, ".about[data-opt=A] summary")
	s.wantContains(t, s.loc(".about[data-opt=A] .sees"), "a look")
	s.wantHidden(t, s.loc(".about[data-opt=A] .onotes"))
	s = newSite(t, siteOpts{})
	s.open(t, "/r/demo/2")
	s.wantVisible(t, s.loc(".orow[data-show=A] .onote"))
	s.wantCount(t, s.loc(".about:visible"), 0)
}

func TestRowClickSelectsAndMoreOfAndAboutFollow(t *testing.T) {
	s := newTodaySite(t)
	s.click(t, `.opts .orow[data-show=B]`)
	s.wantClass(t, s.loc(`.orow[data-show=B]`), "sel")
	failIf(t, expect.Locator(s.loc(`.orow[data-show=A]`)).Not().ToHaveClass(regexp.MustCompile(`(^|\s)sel(\s|$)`)))
	s.wantVisible(t, s.loc(`.moreof [data-opt=B]`))
	s.wantVisible(t, s.loc(`.about[data-opt=B]`))
	s.wantHidden(t, s.loc(`.moreof [data-opt=A]`))
	s.wantHidden(t, s.loc(`.about[data-opt=A]`))
}

func TestControlSwapKeepsRowMoreOfAndAboutOnTheShownLetter(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.open(t, "/r/p2-3b-dock/1")
	s.press(t, "b")
	s.press(t, "0")
	s.wantVisible(t, s.loc(`.ostage[data-opt=today]`))
	s.press(t, "s")
	s.wantContains(t, s.loc(`[data-key=s]`).First(), "1280 x 800")
	s.wantClass(t, s.loc(`.orow[data-show=B]`), "sel")
	s.wantCount(t, s.loc(`.orow.sel`), 1)
	s.wantVisible(t, s.loc(`.moreof [data-opt=B]`))
	s.wantVisible(t, s.loc(`.about[data-opt=B]`))
	s.wantHidden(t, s.loc(`.ostage[data-opt=today]`))
	pick := s.loc(".rpanel button.pick")
	failIf(t, expect.Locator(pick).ToBeEnabled())
	s.wantContains(t, pick, "Pick B")
	s.press(t, "0")
	s.press(t, "w")
	s.wantClass(t, s.loc(`.tile[data-opt=B]`), "sel")
	s.wantClass(t, s.loc(`.orow[data-show=B]`), "sel")
	s.wantVisible(t, s.loc(`.moreof [data-opt=B]`))
	s.wantVisible(t, s.loc(`.about[data-opt=B]`))
	failIf(t, expect.Locator(pick).ToBeEnabled())
	s.wantContains(t, pick, "Pick B")
}

// tabCheck says what is wrong with the Pick's tab: it must sit on the button's top edge, left-aligned, clear of the option rows.
const tabCheck = `() => {
	const r = (sel) => document.querySelector(sel).getBoundingClientRect();
	const tab = r('.act .ptab'), pick = r('.act .pick'), rows = r('.opts');
	const ok = Math.abs(tab.bottom - pick.top) < 1 && Math.abs(tab.left - pick.left) < 1 && tab.top > rows.bottom && pick.height === 44;
	return ok ? '' : 'tab ' + tab.left + ',' + tab.top + ' to ' + tab.bottom + '; pick ' + pick.left + ',' + pick.top + ' h ' + pick.height + '; rows end ' + rows.bottom;
}`

func TestClaudesPickIsATabOnPickOnly(t *testing.T) {
	s := newTodaySite(t)
	tab := s.loc(".rpanel .act .ptab")
	width := `document.querySelector('.rpanel button.pick').getBoundingClientRect().width`
	s.wantCount(t, s.loc(".orow .tag.cp"), 0)
	s.wantHidden(t, tab)
	without := eval(t, s.Page, width)
	s.press(t, "b")
	s.wantVisible(t, tab)
	if got := eval(t, s.Page, tabCheck); got != "" {
		t.Errorf("one at a time: %v", got)
	}
	if with := eval(t, s.Page, width); with != without {
		t.Errorf("Pick width %v with the tab, %v without", with, without)
	}
	s.press(t, "a")
	s.wantHidden(t, tab)
	s.press(t, "b")
	s.press(t, "0")
	s.wantHidden(t, tab)
	s.open(t, "/r/d/1?view=side")
	s.wantCount(t, s.loc(".tile .tag.cp"), 0)
	s.wantHidden(t, tab)
	s.click(t, ".tile[data-opt=B] .ohd")
	s.wantVisible(t, tab)
	if got := eval(t, s.Page, tabCheck); got != "" {
		t.Errorf("side view: %v", got)
	}
	s.open(t, "/r/d/1?show=B")
	s.wantVisible(t, tab)
}

func TestConfirmStepHasNoPickTab(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.open(t, "/r/demo/2")
	s.wantVisible(t, s.loc(".rpanel [value=yes]"))
	s.wantCount(t, s.loc(".ptab"), 0)
}

func TestViewMenuClosedAndKeysStillWork(t *testing.T) {
	s := newTodaySite(t)
	s.wantVisible(t, s.loc(".status .viewmenu summary"))
	if open := eval(t, s.Page, `document.querySelector('.viewmenu').open`); open != false {
		t.Errorf("View menu open = %v, want closed", open)
	}
	s.press(t, "f")
	s.wantClass(t, s.loc("#view"), "true100")
}

func TestTodayAndExtrasSitInTheSamePlaceOnEveryStep(t *testing.T) {
	s := newSite(t, siteOpts{})
	var strips, todays []playwright.Rect
	// Step 5 crops 460 x 260 and has no extras, so neither the picture's shape nor an empty strip may move them.
	for _, step := range []string{"/r/p2-3b-dock/1", "/r/p2-3b-dock/2", "/r/p2-3b-dock/5"} {
		s.open(t, step)
		if step != "/r/p2-3b-dock/5" {
			s.wantVisible(t, s.loc(".moreof [data-opt]:not([hidden]) .extras"))
		}
		failIf(t, expect.Locator(s.loc(".opts .orow").First()).ToHaveAttribute("data-show", "today"))
		if stray := eval(t, s.Page, `[...document.querySelectorAll('.extras')].filter((e) => !e.closest('.moreof, .fold')).length`); stray != 0 {
			t.Errorf("%s: %v extras outside the More of strip", step, stray)
		}
		strips = append(strips, s.rect(t, ".moreof"))
		today := s.rect(t, ".orow[data-show=today]")
		// Its height follows the label's length; its place must not.
		today.Height = 0
		todays = append(todays, today)
	}
	for i := 1; i < len(strips); i++ {
		if !near(strips[i], strips[0]) || !near(todays[i], todays[0]) {
			t.Errorf("step %d: More of %+v and Today %+v, step 1: %+v and %+v", i+1, strips[i], todays[i], strips[0], todays[0])
		}
	}
}

func TestStageZoneIsTheSameForACropAndAFullFrame(t *testing.T) {
	s := newSite(t, siteOpts{})
	for _, vp := range [][2]int{{1440, 900}, {1280, 800}} {
		s.viewport(t, vp[0], vp[1])
		var zones []playwright.Rect
		for _, step := range []string{"/r/p2-3b-dock/1", "/r/p2-3b-dock/5"} {
			s.open(t, step)
			zone := s.rect(t, ".zone")
			zones = append(zones, zone)
			pic := s.rect(t, ".ostage:not([hidden]) .pic")
			dx, dy := (pic.X-zone.X)-(zone.X+zone.Width-pic.X-pic.Width), (pic.Y-zone.Y)-(zone.Y+zone.Height-pic.Y-pic.Height)
			if pic.Width > zone.Width+1 || pic.Height > zone.Height+1 || dx > 2 || dx < -2 || dy > 2 || dy < -2 {
				t.Errorf("%dx%d %s: picture %+v not centred inside the zone %+v", vp[0], vp[1], step, pic, zone)
			}
		}
		if !near(zones[0], zones[1]) {
			t.Errorf("%dx%d: zone %+v on a full frame, %+v on a crop", vp[0], vp[1], zones[0], zones[1])
		}
	}
}

func TestPickNeverMovesBetweenOptionsAndSteps(t *testing.T) {
	const pick = ".rpanel button.pick"
	s := newSite(t, siteOpts{})
	s.viewport(t, 1440, 900)
	s.open(t, "/r/p2-3b-dock/1")
	s.wantContains(t, s.loc(pick), "Pick A")
	want := s.rect(t, pick)
	s.open(t, "/r/p2-3b-dock/5")
	for _, key := range []string{"a", "b", "c", "d"} {
		s.press(t, key)
		s.wantContains(t, s.loc(pick), "Pick "+strings.ToUpper(key))
		if got := s.rect(t, pick); !near(got, want) {
			t.Errorf("step 5, option %s: Pick at %+v, step 1 option A at %+v", key, got, want)
		}
	}
}

func TestStageFitsItsColumnAtTrue100(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.viewport(t, 1280, 800)
	s.open(t, "/r/p2-3b-dock/1?size=1280x800")
	s.press(t, "f")
	s.wantClass(t, s.loc("#view"), "true100")
	s.settle(t)
	zone, col, panel, stage := s.rect(t, ".zone"), s.rect(t, ".cpanel"), s.rect(t, ".rpanel"), s.rect(t, ".zone .stage")
	if zone.X+zone.Width > col.X+col.Width+0.5 {
		t.Errorf("zone %+v leaves its column %+v", zone, col)
	}
	if stage.X < zone.X-0.5 || stage.Y < zone.Y-0.5 || stage.X+stage.Width > zone.X+zone.Width+0.5 || stage.Y+stage.Height > zone.Y+zone.Height+0.5 {
		t.Errorf("stage %+v leaves the zone %+v", stage, zone)
	}
	if panel.X < 0 || panel.Y < 0 || panel.X+panel.Width > 1280.5 || panel.Y+panel.Height > 800.5 {
		t.Errorf("Options panel %+v not inside the 1280 x 800 viewport", panel)
	}
	if zone.X+zone.Width > panel.X+0.5 {
		t.Errorf("zone ends at %v, past the Options panel at %v", zone.X+zone.Width, panel.X)
	}
	if scrolls := eval(t, s.Page, `(() => { const st = document.querySelector('.zone .stage'); return st.scrollWidth > st.clientWidth; })()`); scrolls != true {
		t.Errorf("a 1280 px picture in a narrower stage does not scroll inside it")
	}
	rows, err := s.loc(".rpanel .orow").All()
	failIf(t, err)
	for _, row := range rows {
		s.wantVisible(t, row)
		if r, err := row.BoundingBox(); err != nil || r == nil || r.X < zone.X+zone.Width-0.5 {
			t.Errorf("row %+v (%v) under the zone ending at %v", r, err, zone.X+zone.Width)
		}
	}
}

func TestPickVisibleWithoutScrolling(t *testing.T) {
	s := newSite(t, siteOpts{})
	inside := func(path string, w, h float64) {
		t.Helper()
		r := s.rect(t, ".rpanel button.pick")
		if r.X < 0 || r.Y < 0 || r.X+r.Width > w || r.Y+r.Height > h {
			t.Errorf("%s at %vx%v: Pick at %+v", path, w, h, r)
		}
	}
	s.viewport(t, 1440, 900)
	for _, path := range []string{"/r/p2-3b-dock/1", "/r/p2-3b-dock/2", "/r/p2-3b-dock/3", "/r/p2-3b-dock/4", "/r/p2-3b-dock/5", "/r/p2-3b-dock/6", "/r/demo/10"} {
		s.open(t, path)
		inside(path, 1440, 900)
	}
	// Short enough that six options cannot fit, so the list must scroll inside the panel.
	s.viewport(t, 1280, 540)
	s.open(t, "/r/demo/10")
	inside("/r/demo/10", 1280, 540)
	if scrolls := eval(t, s.Page, `(() => { const o = document.querySelector('.rpanel .opts'); return o.scrollHeight > o.clientHeight; })()`); scrolls != true {
		t.Errorf("six options at 1280 x 540 do not scroll inside the Options list")
	}
	s.wantVisible(t, s.loc(".rpanel .omore"))
	eval(t, s.Page, `(() => { const o = document.querySelector('.rpanel .opts'); o.scrollTop = o.scrollHeight; o.dispatchEvent(new Event('scroll')); })()`)
	s.wantHidden(t, s.loc(".rpanel .omore"))
}

func TestSideViewTilesStayInTheZone(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.viewport(t, 1440, 900)
	s.open(t, "/r/p2-3b-dock/1")
	flip := s.rect(t, ".zone")
	s.open(t, "/r/p2-3b-dock/1?view=side")
	s.wantVisible(t, s.loc(".zone .tile.reft"))
	if side := s.rect(t, ".zone"); !near(side, flip) {
		t.Errorf("zone %+v side by side, %+v one at a time", side, flip)
	}
	s.wantCount(t, s.loc(".zone .tile .ohd"), 4)
	s.wantCount(t, s.loc(".tile :is(p, details, .extras)"), 0)
	if dup := eval(t, s.Page, `(() => { const ids = [...document.querySelectorAll('[id]')].map((e) => e.id); return ids.filter((x, i) => ids.indexOf(x) !== i).join(' '); })()`); dup != "" {
		t.Errorf("ids used twice: %v", dup)
	}
	s.click(t, ".tile[data-opt=C] .ohd")
	s.wantVisible(t, s.loc(".moreof [data-opt=C] .extras"))
	s.wantHidden(t, s.loc(".moreof [data-opt=A]"))
}

func TestConfirmStepPicksFromTheRightPanel(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.open(t, "/r/demo/2")
	s.wantVisible(t, s.loc(".rpanel [value=yes]"))
	s.wantVisible(t, s.loc(".rpanel [value=change]"))
	s.wantCount(t, s.loc(".opts .orow"), 1)
	s.wantCount(t, s.loc(".orow[data-show=today]"), 0)
}

func wantLeftPanel(t *testing.T, s *site, path, title string, chips int) {
	t.Helper()
	t.Run(path, func(t *testing.T) {
		s.open(t, path)
		s.wantCount(t, s.loc(".lpanel #chips .chip"), chips)
		s.wantCount(t, s.loc("#chips"), 1)
		s.wantText(t, s.loc(".lpanel .head h1"), title)
		s.wantCount(t, s.loc(".lpanel details[open]"), 0)
		s.wantCount(t, s.loc(".rpanel .stepnav"), 1)
		s.wantCount(t, s.loc(".lpanel :is(.stepnav, .notebox, .verdict, .gside, .act)"), 0)
	})
}

func TestEveryStepKindHasTheLeftPanel(t *testing.T) {
	s := newSite(t, siteOpts{})
	questions := []string{
		"Which backdrop reads better behind the HUD?", "Is the pile card right as drawn?", "Which wording for the card question?",
		"Which click sound?", "Edit the notice wording", "Does the selection ring read in motion?", "Look through every state",
		"Does the demo pass?", "Which outline weight and unit size read best?", "Which outline weight reads best?",
	}
	for i, q := range questions {
		wantLeftPanel(t, s, fmt.Sprintf("/r/demo/%d", i+1), q, 11)
	}
	// The summary keeps the round's intro open, in the centre column.
	wantLeftPanel(t, s, "/r/demo/summary", "What the server recorded", 11)
	s.wantContains(t, s.loc(".cpanel details[open].intro"), "Demo only")
	wantLeftPanel(t, missingStep(t), "/r/m/2", "[step missing: gone]", 3)
	wantLeftPanel(t, s, "/r/p2-3b-dock/1", "Factory queue: where does it live?", 7)
}

func TestPhoneGalleryAndTuneAreNotTrappedInAScrollBox(t *testing.T) {
	s := newSite(t, siteOpts{})
	for step, parts := range map[string]string{"/r/demo/7": ".gmain .pic, .gside textarea, .thumbs", "/r/demo/9": ".stage .pic, wr-tune"} {
		phone := s.phoneFrame(t, step, ".phone [data-act=sheet]")
		got := eval(t, phone, `(() => {
			const bad = [], d = document.documentElement;
			if (d.scrollWidth > d.clientWidth) bad.push('page scrolls sideways');
			for (const el of document.querySelectorAll('`+parts+`')) {
				const r = el.getBoundingClientRect();
				if (r.width < 200 || r.height < 40) bad.push(el.className || el.tagName + ' is ' + r.width + ' x ' + r.height);
				for (let a = el.parentElement; a && a.id !== 'main'; a = a.parentElement) {
					const o = getComputedStyle(a).overflowY;
					if ((o === 'auto' || o === 'scroll') && a.scrollHeight > a.clientHeight + 1) bad.push((el.className || el.tagName) + ' scrolls inside ' + a.className);
				}
			}
			return bad.join('; ');
		})()`)
		if got != "" {
			t.Errorf("%s on the phone: %v", step, got)
		}
	}
}

func TestGalleryAndTuneControlsNeedNoScroll(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.viewport(t, 1440, 900)
	for step, note := range map[string]string{"/r/demo/7": ".gside textarea", "/r/demo/9": ".notebox textarea"} {
		s.open(t, step)
		s.wantVisible(t, s.loc(note))
		got := eval(t, s.Page, `(() => {
			const bad = [];
			for (const sel of ['`+note+`', '.stepnav [data-key=arrowleft]']) {
				const r = document.querySelector(sel).getBoundingClientRect();
				if (r.top < 0 || r.bottom > innerHeight || r.left < 0 || r.right > innerWidth) bad.push(sel + ' at ' + r.left + ',' + r.top + ' to ' + r.right + ',' + r.bottom);
			}
			return bad.join('; ') + (bad.length ? ' in ' + innerWidth + ' x ' + innerHeight : '');
		})()`)
		if got != "" {
			t.Errorf("%s needs a scroll: %v", step, got)
		}
	}
}

func TestLongNotesClampAndShowInAbout(t *testing.T) {
	s := newSite(t, siteOpts{})
	for _, vp := range [][2]int{{1440, 900}, {1280, 800}} {
		s.viewport(t, vp[0], vp[1])
		s.open(t, "/r/p2-3b-dock/1")
		got := eval(t, s.Page, `(() => {
			const box = document.querySelector('.rpanel .opts').getBoundingClientRect();
			return [...document.querySelectorAll('.rpanel .orow')].map((r) => r.getBoundingClientRect()).filter((r) => r.top < box.top - 0.5 || r.top >= box.bottom).length;
		})()`)
		if got != 0 {
			t.Errorf("%dx%d: %v option rows start outside the visible list", vp[0], vp[1], got)
		}
		s.wantHidden(t, s.loc(".omore"))
	}
	s.press(t, "b")
	s.click(t, ".about[data-opt=B] summary")
	s.wantVisible(t, s.loc(".about[data-opt=B] .onotes"))
	s.wantContains(t, s.loc(".about[data-opt=B] .onotes"), "rather than names")
	// 85 characters, under the loader's limit, yet two lines at 1440 x 900 still cut it.
	s.open(t, "/r/p2-3b-dock/5")
	s.press(t, "b")
	s.click(t, ".about[data-opt=B] summary")
	s.wantVisible(t, s.loc(".about[data-opt=B] .onotes"))
	s.wantContains(t, s.loc(".about[data-opt=B] .onotes"), "until you hover")
}

func TestNeutralAnswerIsExplainedInItsTooltip(t *testing.T) {
	const hint = "Records no winner. Say why in the note."
	s := newSite(t, siteOpts{secret: testSecret})
	tok := "t=" + roundToken("demo")
	for _, path := range []string{"/r/demo/10?" + tok, "/r/demo/10?view=side&" + tok, "/r/demo/9?" + tok} {
		s.open(t, path)
		failIf(t, expect.Locator(s.loc(".act [value=neither]")).ToHaveAttribute("title", hint))
		s.wantCount(t, s.loc(".nexplain"), 0)
	}
	s.open(t, "/r/demo/2?"+tok)
	s.wantVisible(t, s.loc(".act .pick"))
	s.wantCount(t, s.loc("[value=neither]"), 0)
	s.open(t, "/r/demo/10")
	s.wantVisible(t, s.loc("#readonly"))
	s.wantCount(t, s.loc("[value=neither]"), 0)
	open := newSite(t, siteOpts{})
	phone := open.phoneFrame(t, "/r/demo-controls/1", ".phone [data-act=sheet]")
	failIf(t, expect.Locator(phone.Locator(".sheet [value=neither]")).ToHaveAttribute("title", hint))
}

func galleryWithVerdict(t *testing.T) *site {
	t.Helper()
	dir := writeTree(t, map[string]string{
		"index.yaml":   "- {id: g, title: G}\n",
		"g/round.yaml": "title: G\nsteps: [gal]\n",
		"g/gal.yaml":   "kind: gallery\nquestion: Look\nitems: [{id: a, label: A}, {id: b, label: B}]\nverdict: {key: gv, pass: Pass, changes: Changes}\n",
	})
	return newSite(t, siteOpts{rounds: dir})
}

// missingStep serves round m, whose step 2 has no file.
func missingStep(t *testing.T) *site {
	t.Helper()
	dir := writeTree(t, map[string]string{
		"index.yaml":   "- {id: m, title: Missing}\n",
		"m/round.yaml": "title: Missing\nsteps: [ok, gone]\n",
		"m/ok.yaml":    "kind: verdict\nquestion: Still fine?\n",
	})
	return newSite(t, siteOpts{rounds: dir})
}

func TestVerdictSitsInTheRightPanel(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.viewport(t, 1440, 900)
	s.open(t, "/r/demo/8")
	s.wantVisible(t, s.loc(".rpanel .verdict .vb.pick"))
	s.wantVisible(t, s.loc(".rpanel .verdict textarea"))
	s.wantCount(t, s.loc(":is(.lpanel, .cpanel) .verdict"), 0)
	if r := s.rect(t, ".rpanel .stepnav"); r.Y+r.Height > 900 {
		t.Errorf("step buttons end at %v, below the fold", r.Y+r.Height)
	}
	g := galleryWithVerdict(t)
	g.open(t, "/r/g/1")
	g.wantCount(t, g.loc(".rpanel .verdict"), 1)
}

// The first answer button of every kind sits where a choice step's Pick does, inside the right panel.
func TestEveryAnswerSitsAtThePickHeight(t *testing.T) {
	s := newSite(t, siteOpts{})
	g := galleryWithVerdict(t)
	s.viewport(t, 1440, 900)
	g.viewport(t, 1440, 900)
	s.open(t, "/r/demo/1")
	pick := s.rect(t, ".rpanel .act .pick")
	for _, c := range []struct {
		p         *site
		path, sel string
	}{{s, "/r/demo/8", ".vb.pick"}, {s, "/r/demo/9", ".act .pick"}, {s, "/r/demo/5", ".act .pick"}, {g, "/r/g/1", ".verdict .vb"}} {
		c.p.open(t, c.path)
		got, panel := c.p.rect(t, ".rpanel "+c.sel), c.p.rect(t, ".rpanel")
		if got.Y-pick.Y > 1 || pick.Y-got.Y > 1 {
			t.Errorf("%s: answer top %v, choice Pick top %v", c.path, got.Y, pick.Y)
		}
		if got.X < panel.X || got.X+got.Width > panel.X+panel.Width {
			t.Errorf("%s: answer x %v..%v outside the right panel %v..%v", c.path, got.X, got.X+got.Width, panel.X, panel.X+panel.Width)
		}
	}
}

func TestPhonePickHasOneWidthOnEveryStep(t *testing.T) {
	s := newSite(t, siteOpts{})
	var widths []any
	for _, step := range []string{"/r/p2-3b-dock/1", "/r/p2-3b-dock/5", "/r/demo/10"} {
		phone := s.phoneFrame(t, step, ".phone .pick")
		widths = append(widths, eval(t, phone, `document.querySelector('.phone button.pick').getBoundingClientRect().width`))
		if step == "/r/p2-3b-dock/1" {
			if over := eval(t, phone, `(() => { const r = (q) => document.querySelector(q).getBoundingClientRect(); return r('.phone .ptab').right > r('.phone button.pick').right + 0.5; })()`); over != false {
				t.Error("Claude's tab overhangs the phone Pick")
			}
		}
	}
	if widths[0] != widths[1] || widths[0] != widths[2] {
		t.Errorf("phone Pick widths %v, want one width", widths)
	}
}

func TestEyebrowIsOneLine(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.viewport(t, 1440, 900)
	s.open(t, "/r/p2-3b-dock/1")
	eb := s.loc(".lpanel .head .n")
	failIf(t, expect.Locator(eb).ToHaveAttribute("title", "Step 1 of 6 · P2.3b Build from the dock: queue, empty card, counter line"))
	// The ellipsis cuts the end, so the step count must come first to stay visible.
	failIf(t, expect.Locator(eb).ToHaveText(regexp.MustCompile(`^Step 1 of 6 · `)))
	if h := s.rect(t, ".lpanel .head .n").Height; h > 20 {
		t.Errorf("eyebrow %v px tall, want one line", h)
	}
}

func TestStatusIsOneLineWithScaleAndVision(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.viewport(t, 1440, 900)
	s.open(t, "/r/p2-3b-dock/1")
	s.wantVisible(t, s.loc(".status .scale"))
	text := eval(t, s.Page, `document.querySelector('.status .stxt').textContent.replace(/\s+/g, ' ').trim()`)
	if !regexp.MustCompile(`^1280 x 720 · Fit \d+ % · Sand · Plain ground · Normal vision$`).MatchString(text.(string)) {
		t.Errorf("status line %q", text)
	}
	if h := s.rect(t, ".status .stxt").Height; h > 20 {
		t.Errorf("status line %v px tall, want one line", h)
	}
	s.open(t, "/r/demo-controls/4")
	s.wantVisible(t, s.loc(".status .vis"))
	if cut := eval(t, s.Page, `(() => { const v = document.querySelector('.status .vis'); return v.scrollWidth > v.clientWidth + 0.5 || v.getBoundingClientRect().right > document.querySelector('.status .stxt').getBoundingClientRect().right + 0.5; })()`); cut != false {
		t.Error("a long status line cuts the vision value")
	}
}

func TestSideViewTilesFillTheZoneInAGrid(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.viewport(t, 1440, 900)
	cols := func() any {
		return eval(t, s.Page, `new Set([...document.querySelectorAll('.zone .tile')].map((e) => Math.round(e.getBoundingClientRect().left))).size`)
	}
	s.open(t, "/r/p2-3b-dock/1?view=side")
	s.wantCount(t, s.loc(".zone .tile"), 4)
	if n := cols(); n != 2 {
		t.Errorf("four tiles in %v columns, want 2", n)
	}
	if narrow := eval(t, s.Page, `[...document.querySelectorAll('.zone .tile .pic')].filter((p) => p.getBoundingClientRect().width < 340).length`); narrow != 0 {
		t.Errorf("%v tile pictures narrower than 340 px", narrow)
	}
	if tall := eval(t, s.Page, `[...document.querySelectorAll('.zone .tile .ohd')].filter((h) => h.getBoundingClientRect().height > 22).length`); tall != 0 {
		t.Errorf("%v tile headers taller than one line", tall)
	}
	s.open(t, "/r/demo/10?view=side")
	if n := cols(); n != 3 {
		t.Errorf("six tiles in %v columns, want 3", n)
	}
}

func TestMeasuresSitInTheMoreOfBand(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.viewport(t, 1440, 900)
	s.open(t, "/r/demo/10?show=C")
	s.wantVisible(t, s.loc(`[data-measure=C] table`))
	table, band := s.rect(t, `[data-measure=C] table`), s.rect(t, ".moreof")
	if table.Y < band.Y || table.Y+table.Height > band.Y+band.Height+0.5 {
		t.Errorf("measures %+v outside the More of band %+v", table, band)
	}
	if scroll := eval(t, s.Page, `document.documentElement.scrollHeight - innerHeight`); scroll != 0 {
		t.Errorf("the page scrolls %v px at 1440 x 900", scroll)
	}
}

func TestPhoneStripShowsTheCurrentStep(t *testing.T) {
	s := newSite(t, siteOpts{})
	phone := s.phoneFrame(t, "/r/demo/10", ".phone .pick")
	got := eval(t, phone, `(() => {
		const strip = document.querySelector('#chips').getBoundingClientRect(), on = document.querySelector('#chips [aria-current=step]').getBoundingClientRect();
		return on.left >= strip.left - 0.5 && on.right <= strip.right + 0.5 ? '' : 'chip ' + on.left + ' to ' + on.right + ' in a strip ' + strip.left + ' to ' + strip.right;
	})()`)
	if got != "" {
		t.Errorf("current step tab out of view: %v", got)
	}
}

func TestSummaryIntroSitsInTheCentre(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.viewport(t, 1440, 900)
	s.open(t, "/r/demo/summary")
	s.wantContains(t, s.loc(".cpanel details[open].intro"), "Demo only")
	s.wantCount(t, s.loc(".lpanel .intro"), 0)
	s.wantCount(t, s.loc(".rpanel [data-copy-from]"), 1)
	style := func(sel string) any {
		return eval(t, s.Page, `(() => { const c = getComputedStyle(document.querySelector('`+sel+`')); return [c.fontSize, c.fontWeight, c.textTransform].join(' '); })()`)
	}
	if label, count := style(".close .h"), style("#sum h2 .cnt"); label != count {
		t.Errorf("Not answered yet reads %v, the answered count %v; want the same small-caps label", label, count)
	}
	s.viewport(t, 1920, 1080)
	left := s.rect(t, "#sum").X
	for _, sel := range []string{".intro", "h2", ":is(p, .scroll)", ".close"} {
		if x := s.rect(t, "#sum > "+sel).X; x-left > 1 || left-x > 1 {
			t.Errorf("summary %s starts at x=%v, the block at x=%v", sel, x, left)
		}
	}
	if w := s.rect(t, ".cpanel .intro").Width; w < 400 || w > 700 {
		t.Errorf("intro %v px wide, want a reading width", w)
	}
}

func TestMoreOfCaptionsWrapToTwoLines(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.viewport(t, 1440, 900)
	for _, key := range []string{"a", "b", "c"} {
		s.open(t, "/r/p2-3b-dock/1")
		s.press(t, key)
		got := eval(t, s.Page, `(() => {
			const band = document.querySelector('.moreof').getBoundingClientRect(), bad = [];
			for (const c of document.querySelectorAll('.moreof [data-opt]:not([hidden]) figcaption')) {
				const r = c.getBoundingClientRect(), fig = c.closest('figure').getBoundingClientRect();
				if (c.scrollWidth > c.clientWidth + 0.5 || c.scrollHeight > c.clientHeight + 0.5) bad.push('"' + c.textContent + '" cut');
				if (r.height > 40) bad.push('"' + c.textContent + '" ' + r.height + ' px tall');
				if (fig.bottom > band.bottom + 0.5) bad.push('figure ends ' + fig.bottom + ' below the band ' + band.bottom);
			}
			return bad.join('; ');
		})()`)
		if got != "" {
			t.Errorf("option %s: %v", key, got)
		}
	}
}

func TestTrue100KeepsTheStageScrollAcrossOptions(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.viewport(t, 1280, 800)
	s.open(t, "/r/p2-3b-dock/1?size=1280x800")
	s.press(t, "f")
	s.wantClass(t, s.loc("#view"), "true100")
	s.settle(t)
	eval(t, s.Page, `(() => { const st = document.querySelector('.zone .stage'); st.scrollLeft = 120; st.scrollTop = 60; })()`)
	want := eval(t, s.Page, `(() => { const st = document.querySelector('.zone .stage'); return st.scrollLeft + ',' + st.scrollTop; })()`)
	if want == "0,0" {
		t.Fatal("the stage does not scroll at true 100 %")
	}
	s.press(t, "b")
	s.wantContains(t, s.loc(".rpanel button.pick"), "Pick B")
	if got := eval(t, s.Page, `(() => { const st = document.querySelector('.zone .stage'); return st.scrollLeft + ',' + st.scrollTop; })()`); got != want {
		t.Errorf("stage scroll %v after switching, %v before", got, want)
	}
}

func TestPickSitsAtOneHeightOnEveryChoiceStep(t *testing.T) {
	top := func(s *site, sel string) float64 {
		t.Helper()
		s.viewport(t, 1440, 900)
		return s.rect(t, sel).Y
	}
	s := newSite(t, siteOpts{})
	s.viewport(t, 1440, 900)
	s.open(t, "/r/p2-3b-dock/1")
	neutral := top(s, ".rpanel button.pick")
	s.open(t, "/r/demo/2")
	yes := top(s, ".rpanel [value=yes]")
	s.click(t, ".rpanel [value=change]")
	s.wantCount(t, s.loc("#main textarea[autofocus]"), 1)
	s.settle(t)
	hinted := top(s, ".rpanel [value=yes]")
	plain := top(newTodaySite(t), ".rpanel button.pick")
	for name, y := range map[string]float64{"without neutral": plain, "confirm Yes": yes, "confirm Yes with the hint": hinted} {
		if y-neutral > 1 || neutral-y > 1 {
			t.Errorf("%s: top %v, step with neutral %v", name, y, neutral)
		}
	}
}

func TestEnterOnAFocusedFoldOpensItAndPicksNothing(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.open(t, "/r/demo/10")
	eval(t, s.Page, `document.querySelector('.why summary').focus()`)
	s.press(t, "Enter")
	s.settle(t)
	if open := eval(t, s.Page, `document.querySelector('.why').open`); open != true {
		t.Error("Enter on the focused fold did not open it")
	}
	s.wantURL(t, "/r/demo/10")
	if got := s.entries(t); len(got) != 0 {
		t.Errorf("Enter on a fold recorded %v", got)
	}
	s.click(t, ".cpwhy summary")
	if kept := eval(t, s.Page, `document.activeElement === document.querySelector('.cpwhy summary')`); kept != false {
		t.Error("a mouse click leaves the fold focused, so the next Enter would toggle it instead of picking")
	}
}

func TestReadOnlyBannerKeepsTheZonesOnScreen(t *testing.T) {
	s := newSite(t, siteOpts{secret: testSecret})
	s.viewport(t, 1440, 900)
	s.open(t, "/r/demo/10")
	s.wantVisible(t, s.loc("#readonly"))
	for _, sel := range []string{".rpanel .stepnav", ".moreof"} {
		if r := s.rect(t, sel); r.Y+r.Height > 900.5 {
			t.Errorf("%s ends at %v, below the 900 px window", sel, r.Y+r.Height)
		}
	}
}

func TestLoadingBarSpansTheViewportTop(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.viewport(t, 1440, 900)
	s.open(t, "/r/p2-3b-dock/1")
	got := eval(t, s.Page, `(() => {
		document.querySelector('#chips a').classList.add('htmx-request');
		const c = getComputedStyle(document.querySelector('.top'), '::after');
		return [c.position, c.top, c.width].join(' ');
	})()`)
	if got != "fixed 0px 1440px" {
		t.Errorf("loading bar %v, want fixed 0px 1440px", got)
	}
}

func TestEveryPageKeepsTheChoiceStepColumns(t *testing.T) {
	s := newSite(t, siteOpts{})
	m := missingStep(t)
	cols := func(p *site, path string) [3]playwright.Rect {
		p.open(t, path)
		return [3]playwright.Rect{p.rect(t, ".step > .lpanel"), p.rect(t, ".step > .cpanel"), p.rect(t, ".step > .rpanel")}
	}
	sameColumn := func(a, b playwright.Rect) bool {
		a.Y, a.Height, b.Y, b.Height = 0, 0, 0, 0
		return near(a, b)
	}
	for _, vp := range [][2]int{{1440, 900}, {1920, 1080}, {2560, 1440}} {
		s.viewport(t, vp[0], vp[1])
		m.viewport(t, vp[0], vp[1])
		want := cols(s, "/r/demo/1")
		pages := map[string][3]playwright.Rect{"/r/m/2 (missing)": cols(m, "/r/m/2")}
		for _, path := range []string{"/r/demo/summary", "/r/demo/5", "/r/demo/7", "/r/demo/8", "/r/demo/9"} {
			pages[path] = cols(s, path)
		}
		for path, got := range pages {
			for i, name := range []string{"left", "centre", "right"} {
				if !sameColumn(got[i], want[i]) {
					t.Errorf("%dx%d %s: %s column x=%v w=%v, choice step x=%v w=%v", vp[0], vp[1], path, name, got[i].X, got[i].Width, want[i].X, want[i].Width)
				}
			}
		}
	}
}

func TestCentreBlocksSitInTheMiddleOfTheColumn(t *testing.T) {
	s := newSite(t, siteOpts{})
	m := missingStep(t)
	mid := func(r playwright.Rect) float64 { return r.X + r.Width/2 }
	for _, vp := range [][2]int{{1440, 900}, {1920, 1080}} {
		s.viewport(t, vp[0], vp[1])
		m.viewport(t, vp[0], vp[1])
		for _, c := range []struct {
			p           *site
			path, block string
		}{
			{s, "/r/demo/5", ".fields"},
			{s, "/r/demo/summary", "#sum"},
			{s, "/r/demo/9", "wr-tune"},
			{s, "/r/demo/9", ".stage .pic"},
			{m, "/r/m/2", ".missing"},
			{s, "/r/demo/7", ".gmain"},
			{s, "/r/demo/7", ".thumbs > *"},
		} {
			c.p.open(t, c.path)
			// Both ends of a run of blocks, so a row of thumbs counts as one block.
			ends := eval(t, c.p.Page, `[...document.querySelectorAll('.cpanel :is(`+c.block+`)')].map((e) => e.getBoundingClientRect()).reduce((a, r) => [Math.min(a[0], r.left), Math.max(a[1], r.right)], [1e9, -1e9]).join(' ')`).(string)
			var l, r float64
			if _, err := fmt.Sscan(ends, &l, &r); err != nil {
				t.Fatalf("%s: %q: %v", c.block, ends, err)
			}
			want, got := mid(c.p.rect(t, ".step > .cpanel")), (l+r)/2
			if got-want > 2 || want-got > 2 {
				t.Errorf("%dx%d %s: %s centre x=%v, column centre x=%v", vp[0], vp[1], c.path, c.block, got, want)
			}
		}
		m.open(t, "/r/m/2")
		if w, col := m.rect(t, ".cpanel > .missing").Width, m.rect(t, ".step > .cpanel").Width; w > col/2 {
			t.Errorf("%dx%d missing message %v px wide in a %v px column, want its own width", vp[0], vp[1], w, col)
		}
	}
}

func TestGalleryLargeLooksLikeTheStatusLineLarge(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.viewport(t, 1440, 900)
	look := `(() => { const b = document.querySelector(':is(.status, .tools) [data-act=large]'), r = b.getBoundingClientRect(), st = document.querySelector('.cpanel').getBoundingClientRect(), c = getComputedStyle(b);
		return [r.height, c.fontSize, Math.round(st.right - r.right)].join(' '); })()`
	s.open(t, "/r/demo/1")
	want := eval(t, s.Page, look)
	s.open(t, "/r/demo/7")
	if got := eval(t, s.Page, look); got != want {
		t.Errorf("gallery Large (height, font, gap to the column's right) %v, choice step's %v", got, want)
	}
}

func TestPhoneSummaryKeepsCopyBeforeEarlierRounds(t *testing.T) {
	dir := writeTree(t, map[string]string{
		"index.yaml":   "- {id: a, title: A}\n- {id: b, title: B}\n",
		"a/round.yaml": "title: A\nsteps: [v]\n",
		"a/v.yaml":     "kind: verdict\nquestion: Old?\n",
		"b/round.yaml": "title: B\nsteps: [v]\nearlier: [a]\n",
		"b/v.yaml":     "kind: verdict\nquestion: New?\n",
	})
	phone := newSite(t, siteOpts{rounds: dir}).phoneFrame(t, "/r/b/summary", ".close")
	// The gaps it had inside the summary block before Copy moved to the right panel.
	got := eval(t, phone, `(() => {
		const copy = document.querySelector('.copy').getBoundingClientRect();
		return [copy.top - document.querySelector('.close').getBoundingClientRect().bottom, document.querySelector('.sec').getBoundingClientRect().top - copy.bottom].map(Math.round).join(' ');
	})()`)
	if got != "20 28" {
		t.Errorf("Copy sits %v px under Not answered yet and above Earlier rounds, want 20 28", got)
	}
}

// The summary's content, not a fixed-width box around it, sits in the middle of the column.
func TestSummaryContentIsCentredWithOneLeftEdge(t *testing.T) {
	s := newSite(t, siteOpts{})
	check := func(when string) {
		for _, vp := range [][2]int{{1440, 900}, {1920, 1080}} {
			s.viewport(t, vp[0], vp[1])
			s.open(t, "/r/demo/summary")
			// Each block's own content (text, chips, table), so a block stretched wider than its content cannot pass; the intro is a framed box.
			got := eval(t, s.Page, `(() => {
				const rs = [...document.querySelectorAll('.cpanel .sumblock > :not([hidden])')].map((e) => { if (e.matches('.intro')) return e.getBoundingClientRect(); const r = document.createRange(); r.selectNodeContents(e); return r.getBoundingClientRect(); }).filter((r) => r.width > 0);
				const c = document.querySelector('.step > .cpanel').getBoundingClientRect();
				const l = Math.min(...rs.map((r) => r.left)), rt = Math.max(...rs.map((r) => r.right));
				return [(l + rt) / 2 - (c.left + c.right) / 2, Math.max(...rs.map((r) => r.left)) - l].map((x) => x.toFixed(1)).join(' ');
			})()`).(string)
			var off, spread float64
			if _, err := fmt.Sscan(got, &off, &spread); err != nil {
				t.Fatal(err)
			}
			if off > 2 || off < -2 || spread > 1 {
				t.Errorf("%s at %dx%d: content centre %v px off the column centre, left edges %v px apart", when, vp[0], vp[1], off, spread)
			}
		}
	}
	check("nothing answered")
	s.open(t, "/r/demo/8")
	s.click(t, ".vb.pick")
	s.wantURL(t, "/r/demo/9")
	check("one answer")
}

// Primary and secondary answers look and sit the same on every kind that has them.
func TestAnswerButtonsShareOneStyle(t *testing.T) {
	s := newSite(t, siteOpts{})
	g := galleryWithVerdict(t)
	s.viewport(t, 1440, 900)
	g.viewport(t, 1440, 900)
	look := `(() => {
		const p = document.querySelector('.rpanel :is(.act .pick, .verdict .vb.pick)'), q = document.querySelector('.rpanel :is(.act .btn:not(.pick), .verdict .vb:not(.pick))');
		const a = p.getBoundingClientRect(), b = q.getBoundingClientRect(), cp = getComputedStyle(p), cq = getComputedStyle(q);
		return [a.top, a.left, a.width, a.height, b.left, b.width, b.height, b.top - a.bottom].map(Math.round).join(' ')
			+ ' | ' + [cp.fontSize, cp.fontWeight, cq.fontSize, cq.fontWeight, cq.borderTopColor, cq.backgroundColor, p.dataset.key, p.querySelector('kbd')?.textContent].join(' ');
	})()`
	s.open(t, "/r/demo/1")
	want := eval(t, s.Page, look)
	for _, c := range []struct {
		p    *site
		path string
	}{{s, "/r/demo/2"}, {s, "/r/demo/8"}, {s, "/r/demo/9"}, {g, "/r/g/1"}} {
		c.p.open(t, c.path)
		if got := eval(t, c.p.Page, look); got != want {
			t.Errorf("%s answers (primary top left width height, secondary left width height, gap | fonts, secondary border and fill, key, keycap)\n got %v\nwant %v", c.path, got, want)
		}
	}
}

func TestEnterPassesAVerdictButNotFromItsNote(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.open(t, "/r/demo/8")
	failIf(t, s.loc(".rpanel .verdict textarea").Click())
	s.press(t, "Enter")
	s.settle(t)
	s.wantURL(t, "/r/demo/8")
	if v := eval(t, s.Page, `document.querySelector('.rpanel .verdict textarea').value`); v != "\n" {
		t.Errorf("note %q after Enter, want a new line", v)
	}
	failIf(t, s.loc(".rpanel .verdict textarea").Blur())
	failIf(t, s.loc(".rpanel .verdict textarea").Fill(""))
	eval(t, s.Page, `document.activeElement.blur()`)
	s.press(t, "Enter")
	s.wantURL(t, "/r/demo/9")
	passed := false
	for _, e := range s.entries(t) {
		passed = passed || (e.Pick != nil && *e.Pick == "pass")
	}
	if !passed {
		t.Errorf("entries %v, want a pass", s.entries(t))
	}
}

// Every control's edge reads at 3:1 against what it sits on and its label at 4.5:1 (WCAG 1.4.11 and 1.4.3).
const contrastScript = `(() => {
	const rgba = (c) => { const m = c.match(/[\d.]+/g).map(Number); return [m[0], m[1], m[2], m.length > 3 ? m[3] : 1]; };
	const over = (top, under) => top.slice(0, 3).map((v, i) => v * top[3] + under[i] * (1 - top[3])).concat(1);
	const lum = (c) => { const l = c.slice(0, 3).map((v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; }); return 0.2126 * l[0] + 0.7152 * l[1] + 0.0722 * l[2]; };
	const ratio = (a, b) => { const x = lum(a), y = lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); };
	const behind = (el) => {
		const stack = [];
		for (let a = el; a; a = a.parentElement) { const c = rgba(getComputedStyle(a).backgroundColor); if (c[3] > 0) stack.push(c); if (c[3] === 1) break; }
		return stack.reverse().reduce((u, c) => over(c, u), [0, 0, 0, 1]);
	};
	const bad = [];
	const check = (el, pseudo, name) => {
		const r = el.getBoundingClientRect();
		if (!r.width || !r.height || getComputedStyle(el).visibility === 'hidden' || el.matches(':disabled, [aria-disabled=true]')) return;
		const bg = behind(el.parentElement), st = getComputedStyle(el, pseudo), fillC = rgba(st.backgroundColor);
		const fill = fillC[3] > 0 ? over(fillC, bg) : null;
		let edge = fill ? ratio(fill, bg) : 1;
		for (const side of ['Top', 'Right', 'Bottom', 'Left']) {
			const c = rgba(st['border' + side + 'Color']);
			if (parseFloat(st['border' + side + 'Width']) > 0 && st['border' + side + 'Style'] !== 'none' && c[3] > 0) edge = Math.max(edge, ratio(over(c, bg), bg));
		}
		const text = pseudo ? null : ratio(over(rgba(st.color), fill ?? bg), fill ?? bg);
		if (edge < 3 || (text !== null && el.textContent.trim() !== '' && text < 4.5))
			bad.push(name + ' "' + (el.textContent.trim().slice(0, 20) || el.className) + '" edge ' + edge.toFixed(2) + (text === null ? '' : ' label ' + text.toFixed(2)));
	};
	for (const sel of ['.btn', '.orow', 'textarea']) for (const el of document.querySelectorAll(sel)) check(el, null, sel);
	for (const el of document.querySelectorAll('wr-tune .tp-sldv_t')) check(el, '::before', 'slider track');
	for (const el of document.querySelectorAll('wr-tune .tp-sldv_k')) check(el, '::after', 'slider knob');
	return bad.join('\n');
})()`

func TestControlsMeetContrast(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.viewport(t, 1440, 900)
	for _, path := range []string{"/r/demo/1", "/r/demo/8", "/r/demo/9", "/r/demo/summary"} {
		s.open(t, path)
		if path == "/r/demo/9" {
			s.wantVisible(t, s.loc("wr-tune .tp-sldv_k").First())
		}
		if bad := eval(t, s.Page, contrastScript); bad != "" {
			t.Errorf("%s below 3:1 edge or 4.5:1 label:\n%v", path, bad)
		}
	}
	if bad := eval(t, s.phoneFrame(t, "/r/demo/1", ".phone [data-act=sheet]"), contrastScript); bad != "" {
		t.Errorf("phone /r/demo/1 below 3:1 edge or 4.5:1 label:\n%v", bad)
	}
}
