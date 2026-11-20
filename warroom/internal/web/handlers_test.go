package web

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"wargrid/warroom/internal/store"
)

var fixtureRounds = map[string]string{
	"index.yaml":   "- {id: r, title: Round R}\n- {id: d, title: Demo D, demo: true}\n",
	"r/round.yaml": "prefix: pre\ntitle: Round R\nsteps: [pic, conf, gal, ver, wor]\n",
	"r/pic.yaml":   "kind: pictures\nquestion: Which one?\nneutral: Neither\noptions:\n  A: {name: First, img: a.png}\n  B: {name: Second, img: b.png}\n",
	"r/conf.yaml":  "kind: pictures\nquestion: Right as drawn?\noptions:\n  A: {name: Only, img: a.png}\n",
	"r/gal.yaml":   "kind: gallery\nquestion: Look\nitems: [{id: a, label: A}, {id: b, label: B}]\nverdict: {key: gv, pass: Pass, changes: Changes}\n",
	"r/ver.yaml":   "kind: verdict\nquestion: Pass?\n",
	"r/wor.yaml":   "kind: wording\nquestion: Edit\nfields: [{id: f1, label: F, text: t}]\n",
	"d/round.yaml": "title: Demo D\nsteps: [x]\n",
	"d/x.yaml":     "kind: pictures\nquestion: Demo?\noptions: {A: {name: a}}\n",
}

type testApp struct {
	*Server
	h     http.Handler
	picks string
}

func newApp(t *testing.T) *testApp { return newAppWith(t, fixtureRounds) }

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

func newAppWith(t *testing.T, roundFiles map[string]string) *testApp {
	t.Helper()
	roundsDir := writeTree(t, roundFiles)
	root := writeTree(t, map[string]string{
		"docs/a.txt":          "doc",
		"docs/sub/b.txt":      "sub",
		"web/site/index.html": "<p>lab</p>",
		"game/g.txt":          "game",
		"tools/t.txt":         "tool",
		"README.md":           "readme",
	})
	if err := os.WriteFile(filepath.Join(filepath.Dir(root), "outside.txt"), []byte("outside"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(filepath.Join(filepath.Dir(root), "outside.txt"), filepath.Join(root, "docs", "link.txt")); err != nil {
		t.Fatal(err)
	}
	picks := filepath.Join(t.TempDir(), "data", "picks.json")
	srv := NewServer(&Config{Root: root, Picks: picks, Rounds: roundsDir})
	return &testApp{Server: srv, h: srv.Routes(), picks: picks}
}

func (a *testApp) do(method, target string, body io.Reader, contentType string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(method, target, body)
	if contentType != "" {
		req.Header.Set("Content-Type", contentType)
	}
	rec := httptest.NewRecorder()
	a.h.ServeHTTP(rec, req)
	return rec
}

func (a *testApp) get(target string) *httptest.ResponseRecorder {
	return a.do(http.MethodGet, target, nil, "")
}

func (a *testApp) post(target string, form url.Values) *httptest.ResponseRecorder {
	return a.do(http.MethodPost, target, strings.NewReader(form.Encode()), "application/x-www-form-urlencoded")
}

// ServeMux answers a path with dots or a missing trailing slash by redirecting to the cleaned one; the cleaned one is what must be refused.
func (a *testApp) follow(rec *httptest.ResponseRecorder, again func(target string) *httptest.ResponseRecorder) *httptest.ResponseRecorder {
	if rec.Code == http.StatusMovedPermanently || rec.Code == http.StatusTemporaryRedirect || rec.Code == http.StatusPermanentRedirect {
		return again(rec.Header().Get("Location"))
	}
	return rec
}

func (a *testApp) getFollowing(target string) *httptest.ResponseRecorder {
	return a.follow(a.get(target), a.get)
}

func (a *testApp) saved(t *testing.T) map[string]store.Entry {
	t.Helper()
	raw, err := os.ReadFile(a.picks)
	if err != nil {
		t.Fatal(err)
	}
	var got map[string]store.Entry
	if err := json.Unmarshal(raw, &got); err != nil {
		t.Fatal(err)
	}
	return got
}

func wantStatus(t *testing.T, rec *httptest.ResponseRecorder, want int) {
	t.Helper()
	if rec.Code != want {
		t.Fatalf("status %d, want %d: %s", rec.Code, want, rec.Body.String())
	}
}

func TestHealth(t *testing.T) {
	rec := newApp(t).get("/health")
	wantStatus(t, rec, 200)
	if rec.Body.String() != "ok" {
		t.Fatalf("body %q", rec.Body.String())
	}
}

func TestRoundListHidesDemoRounds(t *testing.T) {
	a := newApp(t)
	body := a.get("/").Body.String()
	if !strings.Contains(body, "Round R") || strings.Contains(body, "Demo D") {
		t.Fatalf("list = %s", body)
	}
	if body := a.get("/?demo=1").Body.String(); !strings.Contains(body, "Demo D") {
		t.Fatalf("demo list = %s", body)
	}
}

func TestLoadErrorsShowAsABanner(t *testing.T) {
	a := newApp(t)
	if err := os.Remove(filepath.Join(a.cfg.Rounds, "r", "ver.yaml")); err != nil {
		t.Fatal(err)
	}
	if body := a.get("/").Body.String(); !strings.Contains(body, "[step missing: ver]") {
		t.Fatalf("no banner: %s", body)
	}
}

func TestRoundsReloadOnEveryRequest(t *testing.T) {
	a := newApp(t)
	step := filepath.Join(a.cfg.Rounds, "r", "pic.yaml")
	if err := os.WriteFile(step, []byte("kind: pictures\nquestion: Edited question?\noptions: {A: {name: x}}\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if body := a.get("/r/r/1").Body.String(); !strings.Contains(body, "Edited question?") {
		t.Fatalf("page = %s", body)
	}
}

func TestOpenRoundGoesToTheFirstUnansweredStep(t *testing.T) {
	a := newApp(t)
	rec := a.get("/r/r?show=B")
	wantStatus(t, rec, http.StatusFound)
	if loc := rec.Header().Get("Location"); loc != "/r/r/1?show=B" {
		t.Fatalf("location %q", loc)
	}
	wantStatus(t, a.post("/r/r/pic/pick", url.Values{"pick": {"A"}}), 303)
	if loc := a.get("/r/r").Header().Get("Location"); loc != "/r/r/2" {
		t.Fatalf("after a pick: %q", loc)
	}
	for _, p := range []struct{ step, pick string }{{"conf", "yes"}, {"gal", "pass"}, {"ver", "pass"}} {
		wantStatus(t, a.post("/r/r/"+p.step+"/pick", url.Values{"pick": {p.pick}}), 303)
	}
	if loc := a.get("/r/r").Header().Get("Location"); loc != "/r/r/summary" {
		t.Fatalf("all answered: %q", loc)
	}
}

func TestStepAndSummaryPages(t *testing.T) {
	a := newApp(t)
	if body := a.get("/r/r/1").Body.String(); !strings.Contains(body, "Which one?") || !strings.Contains(body, "Second") {
		t.Fatalf("step 1 = %s", body)
	}
	wantStatus(t, a.get("/r/r/summary"), 200)
	for _, target := range []string{"/r/r/0", "/r/r/6", "/r/r/x", "/r/nope", "/r/nope/1", "/r/nope/summary", "/r/..%2Fr/1"} {
		if rec := a.get(target); rec.Code != 404 {
			t.Errorf("GET %s = %d, want 404", target, rec.Code)
		}
	}
}

func TestPickWritesTheOldKeyFormat(t *testing.T) {
	a := newApp(t)
	wantStatus(t, a.post("/r/r/pic/pick", url.Values{"pick": {"B"}, "note": {"fine"}}), 303)
	wantStatus(t, a.post("/r/r/gal/pick", url.Values{"pick": {"changes"}}), 303)
	got := a.saved(t)
	if p := got["pre:pic"].Pick; p == nil || *p != "B" || got["pre:pic"].Note != "fine" {
		t.Fatalf("pre:pic = %+v", got["pre:pic"])
	}
	if p := got["pre:gv"].Pick; p == nil || *p != "changes" {
		t.Fatalf("the gallery verdict goes to its own key: %v", got)
	}
	rec := a.get("/picks.json")
	wantStatus(t, rec, 200)
	var served map[string]store.Entry
	if err := json.Unmarshal(rec.Body.Bytes(), &served); err != nil || len(served) != 2 {
		t.Fatalf("picks.json = %s, %v", rec.Body.String(), err)
	}
	if rec.Header().Get("Cache-Control") != "no-store" {
		t.Fatal("picks.json must not be cached")
	}
}

func TestPickAnswerWords(t *testing.T) {
	a := newApp(t)
	cases := []struct{ step, pick string }{{"pic", "neither"}, {"conf", "yes"}, {"ver", "pass"}, {"ver", "changes"}, {"gal", "pass"}}
	for _, tc := range cases {
		wantStatus(t, a.post("/r/r/"+tc.step+"/pick", url.Values{"pick": {tc.pick}}), 303)
	}
}

func TestPickKeepsTheNoteWhenNoneIsSent(t *testing.T) {
	a := newApp(t)
	wantStatus(t, a.post("/r/r/pic/pick", url.Values{"pick": {"A"}, "note": {"keep me"}}), 303)
	wantStatus(t, a.post("/r/r/pic/pick", url.Values{"pick": {"B"}}), 303)
	if e := a.saved(t)["pre:pic"]; *e.Pick != "B" || e.Note != "keep me" {
		t.Fatalf("entry = %+v", e)
	}
}

func TestBadPicksAreRejectedAndNotWritten(t *testing.T) {
	a := newApp(t)
	bad := []struct {
		name, target string
		form         url.Values
	}{
		{"letter the step lacks", "/r/r/pic/pick", url.Values{"pick": {"C"}}},
		{"lowercase letter", "/r/r/pic/pick", url.Values{"pick": {"a"}}},
		{"script", "/r/r/pic/pick", url.Values{"pick": {"<script>"}}},
		{"too long", "/r/r/pic/pick", url.Values{"pick": {strings.Repeat("A", 17)}}},
		{"yes on a two-option step", "/r/r/pic/pick", url.Values{"pick": {"yes"}}},
		{"neither where there is no neutral", "/r/r/conf/pick", url.Values{"pick": {"neither"}}},
		{"nothing at all", "/r/r/pic/pick", url.Values{}},
		{"empty pick without a note", "/r/r/pic/pick", url.Values{"pick": {""}}},
		{"pick on wording", "/r/r/wor/pick", url.Values{"pick": {"A"}}},
		{"verdict word on a picture step", "/r/r/pic/pick", url.Values{"pick": {"pass"}}},
		{"overlong note", "/r/r/pic/pick", url.Values{"pick": {"A"}, "note": {strings.Repeat("x", maxNote+1)}}},
		{"invalid utf-8 note", "/r/r/pic/pick", url.Values{"pick": {"A"}, "note": {"\xff\xfe"}}},
		{"body over the cap", "/r/r/pic/pick", url.Values{"pick": {"A"}, "note": {strings.Repeat("x", maxBody)}}},
	}
	for _, tc := range bad {
		if rec := a.post(tc.target, tc.form); rec.Code != 400 {
			t.Errorf("%s: status %d, want 400", tc.name, rec.Code)
		}
	}
	if _, err := os.Stat(a.picks); !os.IsNotExist(err) {
		t.Fatalf("a bad request wrote the file: %v", err)
	}
}

func TestPickNeedsAFormBody(t *testing.T) {
	a := newApp(t)
	for _, ct := range []string{"", "application/json", "text/plain"} {
		rec := a.do(http.MethodPost, "/r/r/pic/pick", strings.NewReader(`{"pick":"A"}`), ct)
		wantStatus(t, rec, 400)
	}
	wantStatus(t, a.do(http.MethodPost, "/r/r/pic/pick", nil, ""), 400)
}

func TestPickOnUnknownRoundOrStepIs404(t *testing.T) {
	a := newApp(t)
	for _, target := range []string{"/r/nope/pic/pick", "/r/r/nope/pick", "/r/r/../pick", "/r/other/pic/pick"} {
		rec := a.follow(a.post(target, url.Values{"pick": {"A"}}), func(to string) *httptest.ResponseRecorder { return a.post(to, url.Values{"pick": {"A"}}) })
		if rec.Code != 404 && rec.Code != http.StatusMethodNotAllowed {
			t.Errorf("POST %s = %d, want 404", target, rec.Code)
		}
	}
	wantStatus(t, a.get("/r/r/pic/pick"), http.StatusMethodNotAllowed)
}

func TestDemoRoundsAcceptPicks(t *testing.T) {
	a := newApp(t)
	wantStatus(t, a.post("/r/d/x/pick", url.Values{"pick": {"yes"}}), 303)
	if _, ok := a.saved(t)["d:x"]; !ok {
		t.Fatal("demo pick not written")
	}
}

func TestNoteKeepsThePick(t *testing.T) {
	a := newApp(t)
	wantStatus(t, a.post("/r/r/pic/pick", url.Values{"pick": {"A"}}), 303)
	wantStatus(t, a.post("/r/r/pic/note", url.Values{"note": {"later thought"}}), 200)
	if e := a.saved(t)["pre:pic"]; *e.Pick != "A" || e.Note != "later thought" {
		t.Fatalf("entry = %+v", e)
	}
}

func TestNoteKeys(t *testing.T) {
	a := newApp(t)
	cases := []struct{ step, sub, key string }{
		{"pic", "", "pre:pic"},
		{"gal", "a", "pre:gal:a"},
		{"gal", "", "pre:gv"},
		{"wor", "f1", "pre:wor:f1"},
		{"ver", "", "pre:ver"},
	}
	for _, tc := range cases {
		wantStatus(t, a.post("/r/r/"+tc.step+"/note", url.Values{"note": {"n"}, "sub": {tc.sub}}), 200)
		if e, ok := a.saved(t)[tc.key]; !ok || e.Pick != nil || e.Note != "n" {
			t.Errorf("%s/%s: %q = %+v, want a note with pick null", tc.step, tc.sub, tc.key, e)
		}
	}
}

func TestBadNotesAreRejected(t *testing.T) {
	a := newApp(t)
	bad := []struct {
		step string
		form url.Values
	}{
		{"wor", url.Values{"note": {"n"}}},
		{"wor", url.Values{"note": {"n"}, "sub": {"nope"}}},
		{"gal", url.Values{"note": {"n"}, "sub": {"nope"}}},
		{"pic", url.Values{"note": {"n"}, "sub": {"a"}}},
		{"pic", url.Values{}},
		{"pic", url.Values{"note": {strings.Repeat("x", maxNote+1)}}},
		{"pic", url.Values{"note": {"\xc3\x28"}}},
		{"pic", url.Values{"note": {"n"}, "sub": {"../x"}}},
	}
	for i, tc := range bad {
		if rec := a.post("/r/r/"+tc.step+"/note", tc.form); rec.Code != 400 {
			t.Errorf("case %d (%s): status %d, want 400", i, tc.step, rec.Code)
		}
	}
	if _, err := os.Stat(a.picks); !os.IsNotExist(err) {
		t.Fatalf("a bad note wrote the file: %v", err)
	}
}

func TestNoteAtTheCapIsKept(t *testing.T) {
	a := newApp(t)
	wantStatus(t, a.post("/r/r/pic/note", url.Values{"note": {strings.Repeat("x", maxNote)}}), 200)
}

func TestNewKeysPastTheCapAre507(t *testing.T) {
	a := newApp(t)
	full := map[string]store.Entry{}
	for i := range 500 {
		full[fmt.Sprintf("old:k%d", i)] = store.Entry{}
	}
	raw, err := json.Marshal(full)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Dir(a.picks), 0o750); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(a.picks, raw, 0o600); err != nil {
		t.Fatal(err)
	}
	wantStatus(t, a.post("/r/r/pic/pick", url.Values{"pick": {"A"}}), http.StatusInsufficientStorage)
	wantStatus(t, a.post("/r/r/pic/note", url.Values{"note": {"n"}}), http.StatusInsufficientStorage)
}

func TestFailedWriteIs500AndKeepsTheFile(t *testing.T) {
	a := newApp(t)
	wantStatus(t, a.post("/r/r/pic/pick", url.Values{"pick": {"A"}}), 303)
	dir := filepath.Dir(a.picks)
	if err := os.Chmod(dir, 0o500); err != nil { //nolint:gosec // a read-only directory is how the write fails
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Chmod(dir, 0o700) }) //nolint:gosec // lets TempDir clean up
	wantStatus(t, a.post("/r/r/conf/pick", url.Values{"pick": {"yes"}}), 500)
	if got := a.saved(t); len(got) != 1 {
		t.Fatalf("file = %v", got)
	}
}

func TestUnreadablePicksFileIs500AndKept(t *testing.T) {
	a := newApp(t)
	if err := os.MkdirAll(filepath.Dir(a.picks), 0o750); err != nil {
		t.Fatal(err)
	}
	for _, text := range []string{"{not json", `["pre:pic"]`, `{"pre:pic": null}`} {
		if err := os.WriteFile(a.picks, []byte(text), 0o600); err != nil {
			t.Fatal(err)
		}
		wantStatus(t, a.get("/picks.json"), 500)
		wantStatus(t, a.post("/r/r/pic/pick", url.Values{"pick": {"A"}}), 500)
		wantStatus(t, a.post("/r/r/pic/note", url.Values{"note": {"n"}}), 500)
		if got, _ := os.ReadFile(a.picks); string(got) != text {
			t.Fatalf("file %q was changed to %q", text, got)
		}
	}
}

func TestConcurrentPostsAllLand(t *testing.T) {
	a := newApp(t)
	steps := []string{"pic", "conf", "ver", "gal"}
	picks := map[string]string{"pic": "A", "conf": "yes", "ver": "pass", "gal": "pass"}
	done := make(chan int, len(steps))
	for _, s := range steps {
		go func() { done <- a.post("/r/r/"+s+"/pick", url.Values{"pick": {picks[s]}}).Code }()
	}
	for range steps {
		if code := <-done; code != 303 {
			t.Errorf("status %d", code)
		}
	}
	if got := a.saved(t); len(got) != 4 {
		t.Fatalf("keys = %v", got)
	}
}

func TestStaticTreesAreServed(t *testing.T) {
	a := newApp(t)
	for target, want := range map[string]string{"/docs/a.txt": "doc", "/docs/sub/b.txt": "sub", "/game/g.txt": "game", "/web/site/index.html": "<p>lab</p>"} {
		rec := a.get(target)
		if rec.Code != 200 || rec.Body.String() != want {
			t.Errorf("GET %s = %d %q, want %q", target, rec.Code, rec.Body.String(), want)
		}
	}
}

func TestStaticRefusesWhatItShouldNot(t *testing.T) {
	a := newApp(t)
	for _, target := range []string{
		"/docs/", "/docs", "/docs/sub/", "/docs/sub", "/web/", "/docs/nope.txt",
		"/tools/t.txt", "/README.md", "/docs/../README.md", "/docs/%2e%2e/README.md",
		"/docs/link.txt", "/docs/..%2f..%2foutside.txt",
	} {
		if rec := a.getFollowing(target); rec.Code != 404 {
			t.Errorf("GET %s = %d, want 404", target, rec.Code)
		}
	}
}

func TestEmbeddedStaticFiles(t *testing.T) {
	a := newApp(t)
	for target, marker := range map[string]string{"/static/app.css": "@layer reset", "/static/htmx.min.js": "htmx", "/static/warroom.js": "htmx:error"} {
		rec := a.get(target)
		if rec.Code != 200 || !strings.Contains(rec.Body.String(), marker) {
			t.Errorf("GET %s = %d, missing %q", target, rec.Code, marker)
		}
	}
	for _, target := range []string{"/static/", "/static", "/static/nope.js", "/static/../handlers.go"} {
		if rec := a.getFollowing(target); rec.Code != 404 {
			t.Errorf("GET %s = %d, want 404", target, rec.Code)
		}
	}
}

func TestMissingRootIs404NotAPanic(t *testing.T) {
	a := newApp(t)
	a.cfg.Root = filepath.Join(t.TempDir(), "gone")
	wantStatus(t, a.get("/docs/a.txt"), 404)
}
