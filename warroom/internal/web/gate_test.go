package web

import (
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
)

func gated(t *testing.T) *testApp {
	t.Helper()
	a := newApp(t).locked()
	a.cookie = ""
	return a
}

func wantGateRefusal(t *testing.T, name string, rec *httptest.ResponseRecorder) {
	t.Helper()
	if rec.Code != http.StatusForbidden || rec.Body.String() != gateText {
		t.Errorf("%s: %d %q, want 403 %q", name, rec.Code, rec.Body.String(), gateText)
	}
	if c := rec.Header().Values("Set-Cookie"); len(c) > 0 {
		t.Errorf("%s: refused request set %v", name, c)
	}
}

func wrCookie(t *testing.T, name string, rec *httptest.ResponseRecorder) *http.Cookie {
	t.Helper()
	var found *http.Cookie
	for _, c := range rec.Result().Cookies() {
		if c.Name == cookieName {
			if found != nil {
				t.Errorf("%s: two %s cookies", name, cookieName)
			}
			found = c
		}
	}
	return found
}

func TestGateRefusesEveryRouteWithoutAToken(t *testing.T) {
	a := gated(t)
	for _, target := range []string{"/", "/r/r", "/r/r/1", "/r/r/summary", "/static/app.css", "/docs/x.png", "/picks.json", "/history.jsonl", "/nope", "/health/x"} {
		wantGateRefusal(t, target, a.get(target))
	}
	wantGateRefusal(t, "pick", a.post("/r/r/pic/pick", url.Values{"pick": {"A"}}))
	wantGateRefusal(t, "note", a.post("/r/r/pic/note", url.Values{"note": {"x"}}))
	rec := a.get("/health")
	if rec.Code != http.StatusOK || rec.Body.String() != "ok" {
		t.Errorf("/health: %d %q", rec.Code, rec.Body.String())
	}
}

func TestGateAdmitsEachTokenKindAndSetsTheCookie(t *testing.T) {
	for name, tok := range map[string]string{"admin": Token(testSecret, AdminScope), "round": roundToken("r"), "other round": roundToken("d"), "viewer": viewerToken} {
		rec := gated(t).get("/r/r/1?t=" + tok)
		if rec.Code != http.StatusOK {
			t.Errorf("%s: status %d", name, rec.Code)
		}
		c := wrCookie(t, name, rec)
		if c == nil {
			t.Errorf("%s: no %s cookie", name, cookieName)
			continue
		}
		if c.Value != tok || !c.HttpOnly || !c.Secure || c.SameSite != http.SameSiteLaxMode || c.Path != "/" || c.MaxAge != 7776000 {
			t.Errorf("%s: cookie %+v", name, c)
		}
	}
}

func TestCookieAloneAdmits(t *testing.T) {
	for name, tok := range map[string]string{"admin": Token(testSecret, AdminScope), "round": roundToken("r"), "viewer": viewerToken} {
		a := gated(t)
		a.cookie = tok
		for _, target := range []string{"/r/r/1", "/static/app.css"} {
			rec := a.get(target)
			if rec.Code != http.StatusOK || wrCookie(t, name, rec) != nil {
				t.Errorf("%s %s: %d, cookie %v", name, target, rec.Code, rec.Header().Values("Set-Cookie"))
			}
		}
	}
}

func TestGateRefusesViewersNotListed(t *testing.T) {
	bob := Token(testSecret, ViewerScope("bob"))
	a := gated(t)
	wantGateRefusal(t, "query", a.get("/r/r/1?t="+bob))
	a.cookie = bob
	wantGateRefusal(t, "cookie", a.get("/r/r/1"))
}

func TestGateRefusesBadCookies(t *testing.T) {
	a := gated(t)
	for _, value := range []string{"", "garbage", roundToken("r")[1:]} {
		req := httptest.NewRequest(http.MethodGet, "/r/r/1", nil)
		req.Header.Set("Cookie", cookieName+"="+value)
		rec := httptest.NewRecorder()
		a.h.ServeHTTP(rec, req)
		wantGateRefusal(t, "cookie "+value, rec)
	}
}

func TestCookieAndQueryTogether(t *testing.T) {
	a := gated(t)
	a.cookie = viewerToken
	rec := a.get("/r/r/1?t=wrong")
	if rec.Code != http.StatusOK || wrCookie(t, "wrong query", rec) != nil {
		t.Errorf("valid cookie, wrong query: %d, cookie %v", rec.Code, rec.Header().Values("Set-Cookie"))
	}
	rec = a.get("/r/r/1?t=" + roundToken("r"))
	if c := wrCookie(t, "round query", rec); rec.Code != http.StatusOK || c == nil || c.Value != roundToken("r") {
		t.Errorf("viewer cookie, round query: %d, cookie %+v", rec.Code, c)
	}
}

func TestViewerIsReadOnly(t *testing.T) {
	a := gated(t)
	body := a.get("/r/r/1?t=" + viewerToken).Body.String()
	mustContain(t, "step", body, `id="readonly"`)
	for _, c := range controlsOfRead {
		if strings.Contains(body, c) {
			t.Errorf("viewer page has %s", c)
		}
	}
	rec := a.post("/r/r/pic/pick?t="+viewerToken, url.Values{"pick": {"A"}})
	if rec.Code != http.StatusForbidden || !strings.Contains(rec.Body.String(), "Read only") {
		t.Errorf("viewer pick: %d %q", rec.Code, rec.Body.String())
	}
}

func TestOpenServerHasNoGate(t *testing.T) {
	rec := newApp(t).get("/r/r/1")
	if rec.Code != http.StatusOK || len(rec.Header().Values("Set-Cookie")) > 0 {
		t.Errorf("open server: %d, cookie %v", rec.Code, rec.Header().Values("Set-Cookie"))
	}
}

func TestCookieOnlyOpensTheGate(t *testing.T) {
	a := gated(t)
	a.cookie = roundToken("r")
	rec := a.post("/r/r/pic/pick", url.Values{"pick": {"A"}})
	if rec.Code != http.StatusForbidden || !strings.Contains(rec.Body.String(), "Read only") {
		t.Errorf("pick by a round-token cookie: %d %q, want 403 Read only", rec.Code, rec.Body.String())
	}
	mustContain(t, "step by a round-token cookie", a.get("/r/r/1").Body.String(), `id="readonly"`)
	a.cookie = Token(testSecret, AdminScope)
	rec = a.get("/picks.json")
	if rec.Code != http.StatusForbidden || !strings.Contains(rec.Body.String(), "admin token needed") {
		t.Errorf("/picks.json by an admin cookie: %d %q", rec.Code, rec.Body.String())
	}
}
