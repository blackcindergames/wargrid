package web

import (
	"crypto/hmac"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"net/http"
)

const (
	tokenParam = "t"
	AdminScope = "admin"
	tokenBytes = 16
	readOnly   = "Read only: this link cannot record."
	// Answers are the owner's: a page without the round's token shows the questions only.
	readOnlyNotice = "Read only: answers are hidden and nothing is recorded. Open the round's write link to answer."
)

// A var so a test can prove every check goes through it.
var constantTimeEqual = subtle.ConstantTimeCompare

// Token is the write token for a round, or for scope AdminScope the read-back token: base64url of the HMAC-SHA256 of the scope, cut to 16 bytes.
func Token(secret, scope string) string {
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(scope))
	return base64.RawURLEncoding.EncodeToString(mac.Sum(nil)[:tokenBytes])
}

// RoundScope keeps a round named "admin" from sharing the admin token.
func RoundScope(id string) string { return "round:" + id }

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
