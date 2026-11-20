package web

import (
	"bytes"
	"encoding/json"
	"errors"
	"html"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"net/url"
	"regexp"
	"strings"
	"testing"
	"wargrid/warroom/internal/store"
)

const testSecret = "test-secret"

func (a *testApp) locked() *testApp {
	a.cfg.Secret = testSecret
	return a
}

func roundToken(id string) string { return Token(testSecret, RoundScope(id)) }

var controlsOfRead = []string{`name="pick"`, `data-note=`, `<textarea`, `id="answer"`, `data-key="enter"`, `hx-post=`}

func TestTokenShape(t *testing.T) {
	tok := Token("s", RoundScope("r"))
	if len(tok) != 22 || strings.ContainsAny(tok, "+/=") {
		t.Errorf("token %q: want 16 bytes as unpadded base64url", tok)
	}
	if tok != Token("s", RoundScope("r")) || tok == Token("s", RoundScope("q")) || tok == Token("t", RoundScope("r")) {
		t.Error("a token is fixed per secret and round")
	}
	if Token("s", RoundScope(AdminScope)) == Token("s", AdminScope) {
		t.Error("a round named admin must not get the admin token")
	}
}

func TestWritesNeedTheRoundsToken(t *testing.T) {
	a := newApp(t).locked()
	good := url.Values{"pick": {"A"}}
	cases := map[string]string{
		"missing":      "/r/r/pic/pick",
		"wrong":        "/r/r/pic/pick?t=" + roundToken("r")[1:] + "x",
		"other round":  "/r/r/pic/pick?t=" + roundToken("d"),
		"admin token":  "/r/r/pic/pick?t=" + Token(testSecret, AdminScope),
		"empty":        "/r/r/pic/pick?t=",
		"note missing": "/r/r/pic/note",
	}
	for name, target := range cases {
		form := good
		if strings.HasSuffix(target, "/note") {
			form = url.Values{"note": {"x"}}
		}
		rec := a.post(target, form)
		if rec.Code != http.StatusForbidden || !strings.Contains(rec.Body.String(), "Read only") {
			t.Errorf("%s: %d %q, want 403", name, rec.Code, rec.Body.String())
		}
	}
	if len(mustEntries(t, a)) != 0 {
		t.Fatal("a refused write recorded something")
	}
	wantStatus(t, a.post("/r/r/pic/pick?t="+roundToken("r"), good), http.StatusSeeOther)
	wantStatus(t, a.post("/r/r/pic/note?t="+roundToken("r"), url.Values{"note": {"n"}}), http.StatusOK)
}

func TestCrossSitePostsAreRefused(t *testing.T) {
	a := newApp(t)
	post := func(site string) int {
		req := httptest.NewRequest(http.MethodPost, "/r/r/pic/pick", strings.NewReader("pick=A"))
		req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
		req.Header.Set("Sec-Fetch-Site", site)
		rec := httptest.NewRecorder()
		a.h.ServeHTTP(rec, req)
		return rec.Code
	}
	if got := post("cross-site"); got != http.StatusForbidden {
		t.Errorf("cross-site pick = %d, want 403", got)
	}
	if len(mustEntries(t, a)) != 0 {
		t.Fatal("a cross-site pick was recorded")
	}
	if got := post("same-origin"); got != http.StatusSeeOther {
		t.Errorf("same-origin pick = %d, want 303", got)
	}
}

func mustEntries(t *testing.T, a *testApp) map[string]store.Entry {
	t.Helper()
	e, err := a.store.Entries()
	if err != nil {
		t.Fatal(err)
	}
	return e
}

func TestUnsetSecretLeavesWritesAndReadBackOpen(t *testing.T) {
	a := newApp(t)
	wantStatus(t, a.post("/r/r/pic/pick", url.Values{"pick": {"A"}}), http.StatusSeeOther)
	wantStatus(t, a.get("/picks.json"), http.StatusOK)
	wantStatus(t, a.get("/history.jsonl"), http.StatusOK)
	body := a.get("/r/r/1").Body.String()
	mustContain(t, "open page", body, `name="pick"`)
	if strings.Contains(body, "Read only") {
		t.Error("an open page says read only")
	}
}

func TestReadBackNeedsTheAdminToken(t *testing.T) {
	a := newApp(t).locked()
	wantStatus(t, a.post("/r/r/pic/pick?t="+roundToken("r"), url.Values{"pick": {"A"}}), http.StatusSeeOther)
	for _, route := range []string{"/picks.json", "/history.jsonl"} {
		for _, q := range []string{"", "?t=nope", "?t=" + roundToken("r")} {
			wantStatus(t, a.get(route+q), http.StatusForbidden)
		}
		rec := a.get(route + "?t=" + Token(testSecret, AdminScope))
		wantStatus(t, rec, http.StatusOK)
		if !strings.Contains(rec.Body.String(), "pre:pic") {
			t.Errorf("%s = %q", route, rec.Body.String())
		}
	}
}

func TestEveryLinkAndRequestCarriesTheToken(t *testing.T) {
	a := newShippedApp(t).locked()
	attr := regexp.MustCompile(`(?:href|action|hx-get|hx-post)="(/r/[^"]*)"`)
	for _, round := range []string{"demo-controls", "p2-3a1-gate-1", "demo"} {
		tok := roundToken(round)
		for _, path := range []string{"/1", "/2", "/summary", "/1?phone=1&ground=dark", "/1?view=side"} {
			body := a.get("/r/" + round + path + sep(path) + "t=" + tok).Body.String()
			found := attr.FindAllStringSubmatch(body, -1)
			if len(found) == 0 {
				t.Fatalf("%s%s: no links found", round, path)
			}
			for _, m := range found {
				link := strings.ReplaceAll(m[1], "&amp;", "&")
				if !strings.Contains(link, "t="+tok) {
					t.Errorf("%s%s: %q lacks the token", round, path, link)
				}
			}
		}
	}
}

func sep(path string) string {
	if strings.Contains(path, "?") {
		return "&"
	}
	return "?"
}

func TestTokenSurvivesRedirectsAndHtmxAnswers(t *testing.T) {
	a := newApp(t).locked()
	tok := roundToken("r")
	rec := a.get("/r/r?t=" + tok)
	if loc := rec.Header().Get("Location"); !strings.Contains(loc, "t="+tok) {
		t.Errorf("open redirect lost the token: %q", loc)
	}
	rec = a.fragment(http.MethodPost, "/r/r/pic/pick?t="+tok, url.Values{"pick": {"A"}})
	wantStatus(t, rec, http.StatusOK)
	if push := rec.Header().Get("HX-Push-Url"); !strings.Contains(push, "t="+tok) {
		t.Errorf("HX-Push-Url lost the token: %q", push)
	}
	plain := a.post("/r/r/pic/pick?t="+tok, url.Values{"pick": {"A"}})
	if loc := plain.Header().Get("Location"); !strings.Contains(loc, "t="+tok) {
		t.Errorf("post redirect lost the token: %q", loc)
	}
}

func TestOversizedOrOddTokensAreDropped(t *testing.T) {
	a := newApp(t).locked()
	for _, bad := range []string{strings.Repeat("a", 65), "a<b", "a b\"c"} {
		body := a.get("/r/r/1?t=" + url.QueryEscape(bad)).Body.String()
		if strings.Contains(body, bad) {
			t.Errorf("token %q echoed into the page", bad)
		}
	}
}

func TestEarlierRoundLinksDoNotCarryThisRoundsToken(t *testing.T) {
	roundFiles := map[string]string{}
	for k, v := range fixtureRounds {
		roundFiles[k] = v
	}
	roundFiles["r/round.yaml"] = "prefix: pre\ntitle: Round R\nsteps: [pic]\nearlier: [d]\n"
	a := newAppWith(t, roundFiles).locked()
	tok := roundToken("r")
	body := a.get("/r/r/1?t=" + tok).Body.String()
	for _, m := range regexp.MustCompile(`href="(/r/d/[^"]*)"`).FindAllStringSubmatch(body, -1) {
		if strings.Contains(m[1], "t=") {
			t.Errorf("link to another round carries a token: %q", m[1])
		}
	}
	if !strings.Contains(body, `href="/r/d/summary`) {
		t.Error("no link to the earlier round")
	}
}

func TestReadOnlyPagesOfEveryKindOfferNoPickOrNote(t *testing.T) {
	a := newShippedApp(t).locked()
	cases := []struct{ round, step, name string }{
		{"demo", "1", "pictures"},
		{"demo", "1?view=side", "side by side"},
		{"demo", "2", "confirm"},
		{"demo", "7", "gallery"},
		{"demo", "8", "verdict"},
		{"demo", "5", "wording"},
		{"demo", "9", "tune"},
		{"demo", "1?phone=1", "phone bar"},
		{"demo", "2?phone=1", "confirm phone bar"},
		{"demo", "9?phone=1", "tune phone bar"},
	}
	for _, c := range cases {
		body := a.get("/r/" + c.round + "/" + c.step).Body.String()
		mustContain(t, c.name, body, `id="readonly"`, html.EscapeString(readOnlyNotice))
		for _, absent := range controlsOfRead {
			if strings.Contains(body, absent) {
				t.Errorf("%s: read-only page has %s", c.name, absent)
			}
		}
		mustContain(t, c.name, body, `data-key="arrowright"`)
		rec := a.get("/r/" + c.round + "/" + c.step + sep(c.step) + "t=" + roundToken(c.round))
		if strings.Contains(rec.Body.String(), "Read only") {
			t.Errorf("%s: a valid token still shows the notice", c.name)
		}
	}
}

func TestReadOnlyWordingShowsTheDraftNotTheRecordedText(t *testing.T) {
	a := newApp(t).locked()
	wantStatus(t, a.post("/r/r/wor/note?t="+roundToken("r"), url.Values{"note": {"my words"}, "sub": {"f1"}}), http.StatusOK)
	body := a.get("/r/r/5").Body.String()
	mustContain(t, "wording", body, "Drafted: t")
	if strings.Contains(body, "my words") || strings.Contains(body, "<textarea") {
		t.Error("read-only wording shows the recorded text or a text area")
	}
}

func TestRoundListHasNoNoticeAndTheSummaryDoes(t *testing.T) {
	a := newApp(t).locked()
	if strings.Contains(a.get("/").Body.String(), "Read only") {
		t.Error("the round list shows the notice")
	}
	mustContain(t, "summary", a.get("/r/r/summary").Body.String(), `id="readonly"`)
}

func TestReadsWithoutATokenShowNoAnswers(t *testing.T) {
	a := newTuneApp(t).locked()
	tok := "?t=" + Token(testSecret, RoundScope("t"))
	wantStatus(t, a.post("/r/t/tune/pick"+tok, url.Values{"pick": {"tuned"}, "value": {`{"outline":3.5,"unit":1.3,"you":"#112233","ground":"dark"}`}, "note": {"secret note"}}), http.StatusSeeOther)
	r := newApp(t).locked()
	w := "?t=" + roundToken("r")
	for _, p := range []struct{ step, pick string }{{"pic", "B"}, {"gal", "changes"}} {
		wantStatus(t, r.post("/r/r/"+p.step+"/pick"+w, url.Values{"pick": {p.pick}, "note": {"hidden " + p.step}}), http.StatusSeeOther)
	}
	wantStatus(t, r.post("/r/r/gal/note"+w, url.Values{"note": {"item words"}, "sub": {"a"}}), http.StatusOK)
	wantStatus(t, r.post("/r/r/wor/note"+w, url.Values{"note": {"my words"}, "sub": {"f1"}}), http.StatusOK)
	answers := []string{"hidden pic", "hidden gal", "item words", "my words", "secret note", "#112233", "3.5", "· B", "Picked", "changed", "B: Second", "Changes"}
	pages := map[string]*testApp{"/r/r/1": r, "/r/r/1?view=side": r, "/r/r/3": r, "/r/r/5": r, "/r/r/summary": r, "/r/t/1": a, "/r/t/summary": a}
	for target, app := range pages {
		body := app.get(target).Body.String()
		for _, ans := range answers {
			if strings.Contains(body, ans) {
				t.Errorf("%s without a token shows %q", target, ans)
			}
		}
	}
	mustContain(t, "summary questions", r.get("/r/r/summary").Body.String(), "Which one?", "Pass?")
	mustContain(t, "with the token", r.get("/r/r/summary"+w).Body.String(), "hidden pic", "B: Second", "item words")
	if loc := r.get("/r/r").Header().Get("Location"); loc != "/r/r/1" {
		t.Errorf("without a token the round opens at %q, not step 1", loc)
	}
}

func TestEnterAndLetterKeysFindNoPickButtonWhenReadOnly(t *testing.T) {
	body := newApp(t).locked().get("/r/r/1").Body.String()
	if strings.Contains(body, `class="pick`) || strings.Contains(body, `data-shown`) {
		t.Error("a read-only page has a pick button the Enter key could click")
	}
}

func TestConstantTimeCompareChecksEveryToken(t *testing.T) {
	var calls int
	orig := constantTimeEqual
	constantTimeEqual = func(x, y []byte) int {
		calls++
		return orig(x, y)
	}
	t.Cleanup(func() { constantTimeEqual = orig })
	a := newApp(t).locked()
	a.post("/r/r/pic/pick?t=wrong", url.Values{"pick": {"A"}})
	a.post("/r/r/pic/pick?t="+roundToken("r"), url.Values{"pick": {"A"}})
	a.get("/picks.json?t=wrong")
	a.get("/r/r/1?t=" + roundToken("r"))
	if calls < 4 {
		t.Errorf("%d token checks went through the constant-time compare, want at least 4", calls)
	}
}

func TestHistoryAndChangedCount(t *testing.T) {
	a := newApp(t)
	post := func(pick string) {
		wantStatus(t, a.post("/r/r/pic/pick", url.Values{"pick": {pick}, "note": {"n"}}), http.StatusSeeOther)
	}
	post("A")
	if strings.Contains(a.get("/r/r/summary").Body.String(), "changed") {
		t.Error("a single pick shows a change count")
	}
	post("A")
	post("B")
	post("A")
	rec := a.get("/history.jsonl")
	lines := strings.Split(strings.TrimSpace(rec.Body.String()), "\n")
	if len(lines) != 3 {
		t.Fatalf("history has %d lines for three changes and one repeat: %q", len(lines), rec.Body.String())
	}
	var first struct {
		T, Key, Note string
		Pick         string
	}
	if err := json.Unmarshal([]byte(lines[0]), &first); err != nil || first.Key != "pre:pic" || first.Pick != "A" || first.Note != "n" || !strings.HasSuffix(first.T, "Z") {
		t.Errorf("first line = %+v, %v", first, err)
	}
	mustContain(t, "summary", a.get("/r/r/summary").Body.String(), "changed 3 times")
	if got := a.saved(t)["pre:pic"]; got.Pick == nil || *got.Pick != "A" {
		t.Errorf("picks.json = %+v", got)
	}
}

func TestRequestLogLeavesTheQueryOut(t *testing.T) {
	var logged bytes.Buffer
	old := slog.Default()
	slog.SetDefault(slog.New(slog.NewTextHandler(&logged, nil)))
	t.Cleanup(func() { slog.SetDefault(old) })
	a := newApp(t).locked()
	rec := httptest.NewRecorder()
	a.Handler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/r/r/1?t=SECRETTOKEN", nil))
	if !strings.Contains(logged.String(), "path=/r/r/1") || strings.Contains(logged.String(), "SECRETTOKEN") {
		t.Errorf("log = %q", logged.String())
	}
}

func TestRecovererAnswers500AndKeepsServing(t *testing.T) {
	var logged bytes.Buffer
	old := slog.Default()
	slog.SetDefault(slog.New(slog.NewTextHandler(&logged, nil)))
	t.Cleanup(func() { slog.SetDefault(old) })
	h := recoverer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { panic("boom") }))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/x", nil))
	wantStatus(t, rec, http.StatusInternalServerError)
	if !strings.Contains(logged.String(), "boom") {
		t.Errorf("panic not logged: %q", logged.String())
	}
	abort := recoverer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { panic(http.ErrAbortHandler) }))
	defer func() {
		if err, _ := recover().(error); !errors.Is(err, http.ErrAbortHandler) {
			t.Error("ErrAbortHandler must pass through")
		}
	}()
	abort.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest(http.MethodGet, "/x", nil))
}

func TestSummaryBeatsTheStepNumberPattern(t *testing.T) {
	a := newApp(t)
	mustContain(t, "summary", a.get("/r/r/summary").Body.String(), "What the server recorded")
	mustContain(t, "step", a.get("/r/r/1").Body.String(), "Which one?")
	wantStatus(t, a.get("/nope"), http.StatusNotFound)
	wantStatus(t, a.get("/r/r/1/extra"), http.StatusNotFound)
}
