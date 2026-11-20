package web

import (
	"crypto/hmac"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"net/http"
	"regexp"
	"wargrid/warroom/internal/rounds"
)

const (
	tokenParam   = "t"
	AdminScope   = "admin"
	tokenBytes   = 16
	cookieName   = "wr"
	cookieMaxAge = 90 * 24 * 60 * 60
	gateText     = "War Room needs your invite link; open it again."
	readOnly     = "Read only: this link cannot record."
	// Answers are the owner's: a page without the round's token shows the questions only.
	readOnlyNotice = "View only: you can look around, nothing you do is recorded"
)

// A var so a test can prove every check goes through it.
var constantTimeEqual = subtle.ConstantTimeCompare

var viewerName = regexp.MustCompile(`^[a-z0-9-]{1,32}$`)

// Token is the write token for a round, for scope AdminScope the read-back token, for a ViewerScope a friend's way in: base64url of the HMAC-SHA256 of the scope, cut to 16 bytes.
func Token(secret, scope string) string {
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(scope))
	return base64.RawURLEncoding.EncodeToString(mac.Sum(nil)[:tokenBytes])
}

// RoundScope keeps a round named "admin" from sharing the admin token.
func RoundScope(id string) string { return "round:" + id }

func ViewerScope(name string) string { return "viewer:" + name }

func ValidViewer(name string) bool { return viewerName.MatchString(name) }

// gate lets in only a request with a valid token in the query or the cookie; a valid query token becomes the cookie.
func (s *Server) gate(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if s.cfg.Secret == "" || r.URL.Path == "/health" {
			next.ServeHTTP(w, r)
			return
		}
		if q := r.URL.Query().Get(tokenParam); s.admits(q) {
			http.SetCookie(w, &http.Cookie{Name: cookieName, Value: q, Path: "/", MaxAge: cookieMaxAge, HttpOnly: true, Secure: true, SameSite: http.SameSiteLaxMode})
			next.ServeHTTP(w, r)
			return
		}
		if c, err := r.Cookie(cookieName); err == nil && s.admits(c.Value) {
			next.ServeHTTP(w, r)
			return
		}
		plain(w, http.StatusForbidden, gateText)
	})
}

// admits is any token this server hands out; LoadCatalog, not catalog(), which would log load errors on every request.
func (s *Server) admits(tok string) bool {
	if tok == "" {
		return false
	}
	if s.tokenOK(AdminScope, tok) {
		return true
	}
	for _, name := range s.cfg.Viewers {
		if s.tokenOK(ViewerScope(name), tok) {
			return true
		}
	}
	for id := range rounds.LoadCatalog(s.cfg.Rounds).Rounds {
		if s.canWrite(id, tok) {
			return true
		}
	}
	return false
}

func (s *Server) tokenOK(scope, got string) bool {
	if s.cfg.Secret == "" {
		return true
	}
	return constantTimeEqual([]byte(got), []byte(Token(s.cfg.Secret, scope))) == 1
}

func (s *Server) canWrite(roundID, got string) bool { return s.tokenOK(RoundScope(roundID), got) }

// adminOnly guards the read-back routes.
func (s *Server) adminOnly(h http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if !s.tokenOK(AdminScope, r.URL.Query().Get(tokenParam)) {
			plain(w, http.StatusForbidden, "admin token needed")
			return
		}
		h(w, r)
	}
}
