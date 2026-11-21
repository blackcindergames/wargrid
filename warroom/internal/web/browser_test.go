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
	for _, sel := range []string{`.ptab`, `.tag.cp`, `.rpanel [name=pick]`, `.rpanel [data-note]`, `.nexplain`} {
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
	s.wantHidden(t, phone.Locator(".nexplain"))
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

func TestSideViewSharedPickRowIsCentredUnderTheGrid(t *testing.T) {
	t.Skip("rewritten in Task 4")
	s := newSite(t, siteOpts{})
	s.open(t, "/r/demo/10?view=side")
	row := s.loc(".tiles + .act")
	s.wantVisible(t, row.Locator(".pick + .nwrap [value=neither]"))
	got := eval(t, s.Page, `(() => {
		const r = (e) => e.getBoundingClientRect();
		const grid = r(document.querySelector('.tiles'));
		const [pick, neutral] = [...document.querySelectorAll('.tiles + .act .btn')].map(r);
		const off = Math.abs((pick.left - grid.left) - (grid.right - neutral.right));
		const mids = [pick, neutral].map((x) => x.top + x.height / 2);
		return off < 1 && Math.abs(mids[0] - mids[1]) < 1 ? '' : 'off centre by ' + off + ', middles ' + mids.join(' and ');
	})()`)
	if got != "" {
		t.Errorf("pick row not one centred row under the grid: %v", got)
	}
	colours := fmt.Sprint(cssOf(t, s.Page, ".tiles + .act .pick", "", "background-color"), " ",
		cssOf(t, s.Page, ".tiles + .act [value=neither]", "", "background-color"), " ",
		cssOf(t, s.Page, ".tiles + .act [value=neither]", "", "border-top-color"))
	if want := amberRGB + " " + quietRGB + " " + mutedRGB; colours != want {
		t.Errorf("Pick fill, neutral fill, neutral edge = %s, want %s", colours, want)
	}
}

// gaps measures, in px, picture to pick row, the neutral hint's row to the Large row, and the Pick button's height.
func (s *site) gaps(t *testing.T, picture string) string {
	t.Helper()
	return fmt.Sprint(eval(t, s.Page, `((picture) => {
		const r = (sel) => document.querySelector(sel)?.getBoundingClientRect();
		const act = r(picture + ' + .act'), tools = r('.tools'), above = r('.act .nexplain') ?? act, pick = document.querySelector('.act .pick');
		return [Math.round(act.top - r(picture).bottom), tools ? Math.round(tools.top - above.bottom) : '-', pick ? pick.offsetHeight : '-'].join(' ');
	})('`+picture+`')`))
}

func TestPickRowsSit16PxFromThePictureAndTheLargeRow(t *testing.T) {
	t.Skip("rewritten in Task 4")
	s := newSite(t, siteOpts{})
	s.open(t, "/r/demo/10")
	if got := s.gaps(t, ".stage"); got != "16 16 44" {
		t.Errorf("one view: stage to pick row, hint to Large row, Pick height = %s, want 16 16 44", got)
	}
	s.open(t, "/r/demo/10?view=side")
	if got := s.gaps(t, ".tiles"); got != "16 - 44" {
		t.Errorf("side view: tiles to pick row, -, Pick height = %s, want 16 - 44", got)
	}
}

func TestNeutralAnswerIsExplainedUnderItsRow(t *testing.T) {
	t.Skip("rewritten in Task 4")
	const hint = "Records no winner. Say why in the note."
	s := newSite(t, siteOpts{secret: testSecret})
	tok := "t=" + roundToken("demo")
	for _, path := range []string{"/r/demo/10?" + tok, "/r/demo/10?view=side&" + tok, "/r/demo/9?" + tok} {
		s.open(t, path)
		s.wantText(t, s.loc(".act .nexplain"), hint)
		if c := cssOf(t, s.Page, ".nexplain", "", "color"); c != mutedRGB {
			t.Errorf("%s: hint colour %v, want --muted %s", path, c, mutedRGB)
		}
		place := eval(t, s.Page, `(() => {
			const r = (e) => e.getBoundingClientRect();
			const hint = r(document.querySelector('.act .nexplain')), btn = r(document.querySelector('.act [value=neither]'));
			const hits = [...document.querySelectorAll('.btn')].map(r).filter((b) => b.width && b.left < hint.right && hint.left < b.right && b.top < hint.bottom && hint.top < b.bottom);
			return Math.abs(hint.left - btn.left) < 1 && hint.top >= btn.bottom && hits.length === 0
				? '' : 'hint ' + hint.left + ',' + hint.top + '; neutral ' + btn.left + ' to ' + btn.bottom + '; overlaps ' + hits.length + ' buttons';
		})()`)
		if place != "" {
			t.Errorf("%s: hint not directly under the neutral answer: %v", path, place)
		}
	}
	s.open(t, "/r/demo/2?"+tok)
	s.wantVisible(t, s.loc(".act .pick"))
	s.wantCount(t, s.loc(".nexplain"), 0)
	s.open(t, "/r/demo/10")
	s.wantVisible(t, s.loc("#readonly"))
	s.wantCount(t, s.loc(".nexplain"), 0)
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

func TestAboutFoldNeverRepeatsTheNotes(t *testing.T) {
	s := newTodaySite(t)
	s.wantContains(t, s.loc(".about[data-opt=A]"), "a look")
	s.wantAbsent(t, s.loc(".about[data-opt=A]"), "first")
	s = newSite(t, siteOpts{})
	s.open(t, "/r/demo/2")
	s.wantVisible(t, s.loc(".orow[data-show=A] .onote"))
	s.wantCount(t, s.loc(".about"), 0)
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

func TestDetailsFoldsStartClosed(t *testing.T) {
	s := newTodaySite(t)
	for _, path := range []string{"/r/d/1", "/r/p2-3b-dock/1"} {
		if path != "/r/d/1" {
			s = newSite(t, siteOpts{})
			s.open(t, path)
		}
		if n, err := s.loc(".lpanel details").Count(); err != nil || n < 4 {
			t.Errorf("%s: %d folds in the left panel (%v), want why, Claude's reason, About and This round", path, n, err)
		}
		s.wantCount(t, s.loc(".lpanel details[open]"), 0)
	}
}

func TestTodayAndExtrasSitInTheSamePlaceOnEveryStep(t *testing.T) {
	s := newSite(t, siteOpts{})
	var rects []any
	for _, step := range []string{"/r/p2-3b-dock/1", "/r/p2-3b-dock/2"} {
		s.open(t, step)
		s.wantVisible(t, s.loc(".moreof [data-opt]:not([hidden]) .extras"))
		failIf(t, expect.Locator(s.loc(".opts .orow").First()).ToHaveAttribute("data-show", "today"))
		if stray := eval(t, s.Page, `[...document.querySelectorAll('.extras')].filter((e) => !e.closest('.moreof, .fold')).length`); stray != 0 {
			t.Errorf("%s: %v extras outside the More of strip", step, stray)
		}
		rects = append(rects, eval(t, s.Page, `JSON.stringify(document.querySelector('.moreof').getBoundingClientRect())`))
	}
	if rects[0] != rects[1] {
		t.Errorf("More of strip moved between steps: %v, then %v", rects[0], rects[1])
	}
}

func TestConfirmStepPicksFromTheRightPanel(t *testing.T) {
	s := newSite(t, siteOpts{})
	s.open(t, "/r/demo/2")
	s.wantVisible(t, s.loc(".rpanel [value=yes]"))
	s.wantVisible(t, s.loc(".rpanel [value=change]"))
	s.wantCount(t, s.loc(".opts .orow"), 1)
	s.wantCount(t, s.loc(".orow[data-show=today]"), 0)
}
