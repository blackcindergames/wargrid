//go:build browser

package web

import (
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"slices"
	"strings"
	"sync/atomic"
	"testing"
	"time"
	"wargrid/warroom/internal/store"

	"github.com/mxschmitt/playwright-go"
)

const installHint = "install it once with: cd warroom && go run github.com/mxschmitt/playwright-go/cmd/playwright install "

var browser playwright.Browser

func TestMain(m *testing.M) {
	os.Exit(runWithBrowser(m))
}

func browserName() string {
	if b := os.Getenv("WARROOM_BROWSER"); b != "" {
		return b
	}
	return "firefox"
}

func runWithBrowser(m *testing.M) int {
	name := browserName()
	hint := installHint + name
	if name == "firefox" && runtime.GOOS == "darwin" {
		dir, err := os.MkdirTemp("", "warroom-moz-app-data")
		if err != nil {
			fmt.Fprintf(os.Stderr, "browser tests: %v\n", err)
			return 1
		}
		defer func() { _ = os.RemoveAll(dir) }()
		// shortcut: macOS 27 denies a terminal-started Firefox its app data (bugzilla 2069536, fixed in Firefox 158); drop once playwright-go ships Playwright 1.65.
		_ = os.Setenv("MOZ_APP_DATA", dir)
	}
	pw, err := playwright.Run(&playwright.RunOptions{SkipInstallBrowsers: true})
	if err != nil {
		fmt.Fprintf(os.Stderr, "browser tests: Playwright is not usable (%v); %s\n", err, hint)
		return 1
	}
	defer func() { _ = pw.Stop() }()
	kinds := map[string]playwright.BrowserType{"firefox": pw.Firefox, "chromium": pw.Chromium}
	kind, ok := kinds[name]
	if !ok {
		fmt.Fprintf(os.Stderr, "browser tests: WARROOM_BROWSER=%q, want firefox or chromium\n", name)
		return 1
	}
	browser, err = kind.Launch(playwright.BrowserTypeLaunchOptions{Headless: playwright.Bool(true), Timeout: playwright.Float(30_000)})
	if err != nil {
		fmt.Fprintf(os.Stderr, "browser tests: %s did not start (%v); %s\n", name, err, hint)
		return 1
	}
	defer func() { _ = browser.Close() }()
	return m.Run()
}

type siteOpts struct {
	rounds string // rounds directory; empty means the shipped rounds
	secret string
}

// site is the whole server in-process with a temp picks file, and one fresh browser page on it.
type site struct {
	*testApp
	URL  string
	Page playwright.Page
	// failWrites answers every POST with 503, as a flaky network or server would.
	failWrites atomic.Bool
}

func newSite(t *testing.T, o siteOpts) *site {
	t.Helper()
	if o.rounds == "" {
		o.rounds = "../../rounds"
	}
	picks := filepath.Join(t.TempDir(), "picks.json")
	srv := NewServer(&Config{Root: "../../..", Picks: picks, Rounds: o.rounds, Secret: o.secret})
	s := &site{testApp: &testApp{Server: srv, picks: picks}}
	routes := srv.Routes()
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case r.Method == http.MethodPost && s.failWrites.Load():
			http.Error(w, "down for the test", http.StatusServiceUnavailable)
		case r.URL.Path == "/_phone":
			// headless Firefox cannot be narrower than 500 px, so a phone is a 390 px same-origin frame
			_, _ = io.WriteString(w, `<!doctype html><iframe src="/r/demo-controls/4" style="width:390px;height:800px;border:0"></iframe>`)
		default:
			routes.ServeHTTP(w, r)
		}
	}))
	t.Cleanup(ts.Close)
	s.URL = ts.URL
	ctx, err := browser.NewContext(playwright.BrowserNewContextOptions{Viewport: &playwright.Size{Width: 1280, Height: 900}})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = ctx.Close() })
	if s.Page, err = ctx.NewPage(); err != nil {
		t.Fatal(err)
	}
	s.Page.SetDefaultTimeout(10_000)
	return s
}

func (s *site) open(t *testing.T, path string) {
	t.Helper()
	if _, err := s.Page.Goto(s.URL + path); err != nil {
		t.Fatal(err)
	}
}

func (s *site) entries(t *testing.T) map[string]store.Entry {
	t.Helper()
	return mustEntries(t, s.testApp)
}

func (s *site) loc(sel string) playwright.Locator { return s.Page.Locator(sel) }

func (s *site) press(t *testing.T, key string) {
	t.Helper()
	if err := s.Page.Keyboard().Press(key); err != nil {
		t.Fatal(err)
	}
}

func (s *site) click(t *testing.T, sel string) {
	t.Helper()
	if err := s.loc(sel).Click(); err != nil {
		t.Fatal(err)
	}
}

func eval(t *testing.T, e interface {
	Evaluate(string, ...any) (any, error)
}, script string,
) any {
	t.Helper()
	v, err := e.Evaluate(script)
	if err != nil {
		t.Fatalf("evaluate %q: %v", script, err)
	}
	return v
}

// settle lets queued messages and timers run when a test must see that something did not happen.
func (s *site) settle(t *testing.T) {
	t.Helper()
	eval(t, s.Page, `new Promise((r) => setTimeout(r, 300))`)
}

func eventually(t *testing.T, what string, ok func() bool) {
	t.Helper()
	for end := time.Now().Add(10 * time.Second); time.Now().Before(end); time.Sleep(50 * time.Millisecond) {
		if ok() {
			return
		}
	}
	t.Fatalf("timed out waiting for %s", what)
}

var expect = playwright.NewPlaywrightAssertions(10_000)

func (s *site) wantVisible(t *testing.T, l playwright.Locator) {
	t.Helper()
	failIf(t, expect.Locator(l).ToBeVisible())
}

func (s *site) wantHidden(t *testing.T, l playwright.Locator) {
	t.Helper()
	failIf(t, expect.Locator(l).ToBeHidden())
}

func (s *site) wantCount(t *testing.T, l playwright.Locator, n int) {
	t.Helper()
	failIf(t, expect.Locator(l).ToHaveCount(n))
}

func (s *site) wantText(t *testing.T, l playwright.Locator, text string) {
	t.Helper()
	failIf(t, expect.Locator(l).ToHaveText(text))
}

func (s *site) wantContains(t *testing.T, l playwright.Locator, text string) {
	t.Helper()
	failIf(t, expect.Locator(l).ToContainText(text))
}

func (s *site) wantAbsent(t *testing.T, l playwright.Locator, text string) {
	t.Helper()
	failIf(t, expect.Locator(l).Not().ToContainText(text))
}

func (s *site) wantClass(t *testing.T, l playwright.Locator, class string) {
	t.Helper()
	failIf(t, expect.Locator(l).ToHaveClass(regexp.MustCompile(`(^|\s)`+class+`(\s|$)`)))
}

func (s *site) wantURL(t *testing.T, path string) {
	t.Helper()
	failIf(t, expect.Page(s.Page).ToHaveURL(s.URL+path))
}

func failIf(t *testing.T, err error) {
	t.Helper()
	if err != nil {
		t.Fatal(err)
	}
}

func (s *site) sceneFrames() []playwright.Frame {
	return slices.DeleteFunc(slices.Clone(s.Page.Frames()), func(f playwright.Frame) bool { return !strings.Contains(f.URL(), "scene.html") })
}

// frameEnding finds the scene frame whose address ends with the given hash parameter.
func (s *site) frameEnding(t *testing.T, suffix string) playwright.Frame {
	t.Helper()
	for _, f := range s.sceneFrames() {
		if strings.HasSuffix(f.URL(), suffix) {
			return f
		}
	}
	t.Fatalf("no scene frame ending in %q", suffix)
	return nil
}

// markFrames stamps every scene document, so a later check can tell a kept document from a reloaded one.
func (s *site) markFrames(t *testing.T) {
	t.Helper()
	for _, f := range s.sceneFrames() {
		eval(t, f, `window.__doc = true`)
	}
}

func (s *site) wantFramesKept(t *testing.T, n int) {
	t.Helper()
	scenes := s.sceneFrames()
	if len(scenes) != n {
		t.Fatalf("%d scene frames, want %d", len(scenes), n)
	}
	for _, f := range scenes {
		if eval(t, f, `window.__doc`) != true {
			t.Errorf("frame %s was reloaded", f.URL())
		}
	}
}

// frameValue reads a script value from a frame; a missing frame document reads as nil.
func frameValue(f playwright.Frame, script string) any {
	v, err := f.Evaluate(script)
	if err != nil {
		return nil
	}
	return v
}

// typeInto replaces a Tweakpane text field's content; Locator.Fill fires a change that Tweakpane reverts.
func (s *site) typeInto(t *testing.T, sel, text string) {
	t.Helper()
	failIf(t, s.loc(sel).First().Click())
	s.press(t, "ControlOrMeta+a")
	failIf(t, s.Page.Keyboard().Type(text))
	s.press(t, "Enter")
}
