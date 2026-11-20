package web

import (
	"errors"
	"log/slog"
	"net/http"
	"time"
)

// statusWriter remembers the status for the request log; Unwrap lets http.ResponseController reach the real writer.
type statusWriter struct {
	http.ResponseWriter
	status int
}

func (w *statusWriter) WriteHeader(code int) {
	w.status = code
	w.ResponseWriter.WriteHeader(code)
}

func (w *statusWriter) Unwrap() http.ResponseWriter { return w.ResponseWriter }

// recoverer turns a handler panic into a 500 and a log line; http.ErrAbortHandler is how a handler aborts on purpose.
func recoverer(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			v := recover()
			if v == nil {
				return
			}
			if err, ok := v.(error); ok && errors.Is(err, http.ErrAbortHandler) {
				panic(v)
			}
			slog.Error("panic", "path", r.URL.Path, "value", v)
			http.Error(w, "internal error", http.StatusInternalServerError)
		}()
		next.ServeHTTP(w, r)
	})
}

// requestLog logs the path only: the query carries write tokens.
func requestLog(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		sw := &statusWriter{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(sw, r)
		slog.Info("request", "method", r.Method, "path", r.URL.Path, "status", sw.status, "ms", time.Since(start).Milliseconds())
	})
}
