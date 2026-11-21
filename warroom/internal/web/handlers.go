package web

import (
	"crypto/sha256"
	"embed"
	"encoding/hex"
	"encoding/json"
	"errors"
	"html"
	"io"
	"io/fs"
	"log/slog"
	"net/http"
	"net/url"
	"os"
	"slices"
	"strconv"
	"strings"
	"sync"
	"unicode/utf8"
	"wargrid/warroom/internal/rounds"
	"wargrid/warroom/internal/store"
)

const (
	// Room for a 4000-character note of 4-byte characters, URL-encoded, plus the other fields.
	maxBody = 64 << 10
	maxNote = 4000
)

// The repository trees rounds may embed; nothing else under the root is served.
var siteTrees = []string{"docs", "game", "web"}

//go:embed all:static
var staticFiles embed.FS

type Config struct {
	Root   string
	Picks  string
	Rounds string
	// Secret signs the tokens; empty leaves every route, writes and read-back open, for local use.
	Secret string
	// Viewers are the friends whose viewer tokens pass the gate.
	Viewers []string
}

type Server struct {
	cfg   *Config
	store *store.Store
	// The catalog reloads on every request, note autosaves included; each loader message logs once per server.
	logged sync.Map
}

func NewServer(cfg *Config) *Server {
	return &Server{cfg: cfg, store: store.NewStore(cfg.Picks)}
}

// Close waits for a picks write still running; call it last, before the process exits.
func (s *Server) Close() { s.store.Close() }

func (s *Server) Routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, _ *http.Request) { plain(w, http.StatusOK, "ok") })
	mux.HandleFunc("GET /picks.json", s.adminOnly(s.picksJSON))
	mux.HandleFunc("GET /history.jsonl", s.adminOnly(s.historyJSONL))
	mux.HandleFunc("GET /{$}", s.roundList)
	mux.HandleFunc("GET /r/{round}", s.openRound)
	// The literal segment beats {n}: ServeMux picks the more specific pattern.
	mux.HandleFunc("GET /r/{round}/summary", s.summary)
	mux.HandleFunc("GET /r/{round}/{n}", s.stepPage)
	mux.HandleFunc("POST /r/{round}/{step}/pick", s.pick)
	mux.HandleFunc("POST /r/{round}/{step}/note", s.note)
	mux.HandleFunc("GET /static/{path...}", func(w http.ResponseWriter, r *http.Request) {
		name := "static/" + r.PathValue("path")
		if tag, ok := staticETags()[name]; ok {
			w.Header().Set("ETag", tag)
		}
		serveFile(w, r, staticFiles, name)
	})
	for _, tree := range siteTrees {
		mux.HandleFunc("GET /"+tree+"/{path...}", func(w http.ResponseWriter, r *http.Request) { s.serveTree(w, r, tree) })
	}
	// Without a secret any page the owner visits could post picks to a local War Room.
	return s.gate(http.NewCrossOriginProtection().Handler(mux))
}

// Handler is Routes with the request log and panic recovery, which tests leave out.
func (s *Server) Handler() http.Handler { return requestLog(recoverer(s.Routes())) }

func plain(w http.ResponseWriter, code int, body string) {
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(code)
	_, _ = io.WriteString(w, body)
}

// serveTree serves one repository tree from the root, no listings; os.Root refuses links that leave it.
func (s *Server) serveTree(w http.ResponseWriter, r *http.Request, tree string) {
	root, err := os.OpenRoot(s.cfg.Root)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	defer func() { _ = root.Close() }()
	serveFile(w, r, root.FS(), tree+"/"+r.PathValue("path"))
}

// Embedded files carry no modification time, so without an ETag a browser could only guess how long to keep them.
var staticETags = sync.OnceValue(func() map[string]string {
	tags := map[string]string{}
	_ = fs.WalkDir(staticFiles, "static", func(name string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		data, err := staticFiles.ReadFile(name)
		sum := sha256.Sum256(data)
		tags[name] = `"` + hex.EncodeToString(sum[:8]) + `"`
		return err
	})
	return tags
})

// serveFile uses ServeContent, not FileServer, which redirects /index.html away (the lab loads web/site/index.html).
func serveFile(w http.ResponseWriter, r *http.Request, fsys fs.FS, name string) {
	if !fs.ValidPath(name) {
		http.NotFound(w, r)
		return
	}
	f, err := fsys.Open(name)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	defer func() { _ = f.Close() }()
	st, err := f.Stat()
	rs, seekable := f.(io.ReadSeeker)
	if err != nil || st.IsDir() || !seekable {
		http.NotFound(w, r)
		return
	}
	// Without it a browser keeps a stale stylesheet or round page after a restart or redeploy.
	w.Header().Set("Cache-Control", "no-cache")
	http.ServeContent(w, r, st.Name(), st.ModTime(), rs)
}

func (s *Server) catalog() *rounds.Catalog {
	c := rounds.LoadCatalog(s.cfg.Rounds)
	for _, e := range c.Errors {
		if _, seen := s.logged.LoadOrStore("error "+e, true); !seen {
			slog.Warn("rounds", "error", e)
		}
	}
	for _, w := range c.Warnings {
		if _, seen := s.logged.LoadOrStore("warning "+w, true); !seen {
			slog.Warn("rounds", "warning", w)
		}
	}
	return c
}

func (s *Server) picksJSON(w http.ResponseWriter, _ *http.Request) {
	entries, err := s.store.Entries()
	if err != nil {
		slog.Error("picks", "error", err)
		http.Error(w, "picks file unreadable", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	out, err := json.Marshal(entries)
	if err != nil {
		http.Error(w, "encode", http.StatusInternalServerError)
		return
	}
	_, _ = w.Write(out)
}

func (s *Server) historyJSONL(w http.ResponseWriter, _ *http.Request) {
	data, err := s.store.History()
	if err != nil {
		slog.Error("history", "error", err)
		http.Error(w, "history unreadable", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/x-ndjson")
	w.Header().Set("Cache-Control", "no-store")
	_, _ = w.Write(data)
}

func (s *Server) roundList(w http.ResponseWriter, r *http.Request) {
	c := s.catalog()
	links := roundLinks(c, r.URL.Query().Get("demo") == "1")
	keys := parseQuery(r.URL.Query()).Keys
	respond(w, r, "War Room", &PageView{Errors: c.Errors, Cvd: "normal", Body: RoundListMain(links), Legend: legendOf(nil, false), Keys: keys})
}

func (s *Server) openRound(w http.ResponseWriter, r *http.Request) {
	round := s.catalog().Round(r.PathValue("round"))
	if round == nil {
		http.NotFound(w, r)
		return
	}
	entries, err := s.store.Entries()
	if err != nil {
		slog.Error("picks", "error", err)
	}
	// Where the round opens would tell a reader which steps are answered.
	if !s.canWrite(round.ID, r.URL.Query().Get(tokenParam)) {
		entries = nil
	}
	target := url.URL{Path: "/r/" + round.ID + "/summary", RawQuery: r.URL.RawQuery}
	if open := round.Open(entries); len(open) > 0 {
		target.Path = "/r/" + round.ID + "/" + strconv.Itoa(open[0]+1)
	}
	http.Redirect(w, r, target.String(), http.StatusFound)
}

// view opens the picks and the repository root a page reads; done closes the root.
func (s *Server) view(r *http.Request, c *rounds.Catalog, round *rounds.Round) (b *builder, errs []string, done func()) {
	entries, err := s.store.Entries()
	errs = c.Errors
	if err != nil {
		slog.Error("picks", "error", err)
		errs = append(slices.Clone(errs), "picks file unreadable: nothing recorded can be shown")
	}
	b = &builder{cat: c, round: round, entries: entries, q: parseQuery(r.URL.Query())}
	b.readOnly = !s.canWrite(round.ID, b.q.Token)
	if b.readOnly {
		b.entries = map[string]store.Entry{}
	}
	root, err := os.OpenRoot(s.cfg.Root)
	if err != nil {
		return b, errs, func() {}
	}
	b.root = root
	return b, errs, func() { _ = root.Close() }
}

func (s *Server) stepPage(w http.ResponseWriter, r *http.Request) {
	c := s.catalog()
	round := c.Round(r.PathValue("round"))
	n, err := strconv.Atoi(r.PathValue("n"))
	if round == nil || err != nil || n < 1 || n > len(round.Loaded) {
		http.NotFound(w, r)
		return
	}
	b, errs, done := s.view(r, c, round)
	defer done()
	if b.q.Shot {
		render(w, r, ShotDocument(b.shotView(&round.Loaded[n-1])))
		return
	}
	respond(w, r, round.Title+" · War Room", b.stepPageView(errs, n, "", ""))
}

func (s *Server) summary(w http.ResponseWriter, r *http.Request) {
	c := s.catalog()
	round := c.Round(r.PathValue("round"))
	if round == nil {
		http.NotFound(w, r)
		return
	}
	b, errs, done := s.view(r, c, round)
	defer done()
	s.loadChanges(b)
	respond(w, r, round.Title+" · War Room", b.summaryPageView(errs))
}

// loadChanges skips a read-only page, whose summary shows no counts.
func (s *Server) loadChanges(b *builder) {
	if b.readOnly {
		return
	}
	var err error
	if b.changes, err = s.store.Changes(); err != nil {
		slog.Error("history", "error", err)
	}
}

func parseForm(w http.ResponseWriter, r *http.Request) (url.Values, bool) {
	r.Body = http.MaxBytesReader(w, r.Body, maxBody)
	if err := r.ParseForm(); err != nil {
		msg := "bad form"
		if _, tooBig := errors.AsType[*http.MaxBytesError](err); tooBig {
			msg = "form body over 64 KiB"
		}
		http.Error(w, msg, http.StatusBadRequest)
		return nil, false
	}
	return r.PostForm, true
}

// noteRefused answers a note that is too long or not UTF-8 and says whether it did.
func noteRefused(w http.ResponseWriter, note string) bool {
	if utf8.ValidString(note) && utf8.RuneCountInString(note) <= maxNote {
		return false
	}
	http.Error(w, "note over 4000 characters or not UTF-8", http.StatusBadRequest)
	return true
}

// stepOf finds the real step a request names and checks the write token; a missing step has no endpoint.
func (s *Server) stepOf(w http.ResponseWriter, r *http.Request) (*rounds.Catalog, *rounds.Round, *rounds.Step, bool) {
	c := s.catalog()
	round := c.Round(r.PathValue("round"))
	if round == nil {
		http.NotFound(w, r)
		return nil, nil, nil, false
	}
	step := round.Step(r.PathValue("step"))
	if step == nil {
		http.NotFound(w, r)
		return nil, nil, nil, false
	}
	if !s.canWrite(round.ID, r.URL.Query().Get(tokenParam)) {
		plain(w, http.StatusForbidden, readOnly)
		return nil, nil, nil, false
	}
	return c, round, step, true
}

func (s *Server) pick(w http.ResponseWriter, r *http.Request) {
	c, round, step, ok := s.stepOf(w, r)
	if !ok {
		return
	}
	form, ok := parseForm(w, r)
	if !ok {
		return
	}
	pick := form.Get("pick")
	note, hasNote := "", form.Has("note")
	if hasNote {
		note = form.Get("note")
	}
	key := step.AnswerKey()
	value, valueOK := step.TunedValue(pick, form.Get("value"))
	if noteRefused(w, note) {
		return
	}
	if key == "" || !valueOK || (pick == "" && !hasNote) || (pick != "" && !step.AcceptsPick(pick)) {
		http.Error(w, "bad pick", http.StatusBadRequest)
		return
	}
	if pick == "change" && strings.TrimSpace(note) == "" {
		s.askForNote(w, r, c, round, step)
		return
	}
	err := s.store.Update(round.Prefix+":"+key, func(e store.Entry) store.Entry {
		if pick != "" {
			e.Pick, e.Value, e.Name = &pick, value, step.Options[pick].Name
		}
		if hasNote {
			e.Note = note
		}
		return e
	})
	if recordFailed(w, err) {
		return
	}
	s.answered(w, r, c, round, step, pick)
}

// askForNote answers Change without a note: the same step again, asking for one.
func (s *Server) askForNote(w http.ResponseWriter, r *http.Request, c *rounds.Catalog, round *rounds.Round, step *rounds.Step) {
	b, errs, done := s.view(r, c, round)
	defer done()
	hint := "Say what to change here, then press Change again."
	// Not show:top: warroom.js scrolls to the note and its hint instead.
	w.Header().Set("HX-Reswap", "innerHTML")
	respond(w, r, round.Title+" · War Room", b.stepPageView(errs, indexOfStep(b.round, step.Key)+1, "", hint))
}

// answered moves on after a recorded pick: a redirect for a plain form post, the next step's page for htmx.
func (s *Server) answered(w http.ResponseWriter, r *http.Request, c *rounds.Catalog, round *rounds.Round, step *rounds.Step, pick string) {
	b, errs, done := s.view(r, c, round)
	defer done()
	n := indexOfStep(round, step.Key) + 1
	next := n + 1
	if step.Kind == "gallery" {
		next = len(round.Loaded) + 1
	}
	target := b.stepHref(next)
	if r.Header.Get("HX-Request") != "true" {
		http.Redirect(w, r, target, http.StatusSeeOther)
		return
	}
	w.Header().Set("HX-Push-Url", target)
	title := round.Title + " · War Room"
	if next > len(round.Loaded) {
		s.loadChanges(b)
		respond(w, r, title, b.summaryPageView(errs))
		return
	}
	respond(w, r, title, b.stepPageView(errs, next, recordedLine(step, step.AnswerKey(), pick), ""))
}

// recordedLine is the line the page shows after a pick; a blind step also says what the letter was.
func recordedLine(step *rounds.Step, key, pick string) string {
	line := "Recorded: " + key + " " + pick + "."
	if o, ok := step.Options[pick]; ok && step.Blind && o.Reveal != "" {
		line += " " + pick + " was " + o.Reveal + "."
	}
	return line
}

func (s *Server) note(w http.ResponseWriter, r *http.Request) {
	_, round, step, ok := s.stepOf(w, r)
	if !ok {
		return
	}
	form, ok := parseForm(w, r)
	if !ok {
		return
	}
	note := form.Get("note")
	suffix := noteKey(step, form.Get("sub"))
	if noteRefused(w, note) {
		return
	}
	if !form.Has("note") || suffix == "" {
		http.Error(w, "bad note", http.StatusBadRequest)
		return
	}
	err := s.store.Update(round.Prefix+":"+suffix, func(e store.Entry) store.Entry {
		e.Note = note
		return e
	})
	if recordFailed(w, err) {
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	_, _ = io.WriteString(w, html.EscapeString("Recorded: note on "+suffix+"."))
}

// noteKey is the picks key (without prefix) a note goes to; "" when the step has no such place for one.
func noteKey(s *rounds.Step, sub string) string {
	switch {
	case s.Kind == "wording" && slices.ContainsFunc(s.Fields, func(f rounds.Field) bool { return f.ID == sub }):
		return s.Key + ":" + sub
	case s.Kind == "gallery" && sub != "":
		if slices.ContainsFunc(s.Items, func(i rounds.Item) bool { return i.ID == sub }) {
			return s.Key + ":" + sub
		}
	case s.Kind == "gallery" && s.Verdict != nil:
		return s.VerdictKey()
	case sub == "" && (s.IsChoice() || s.Kind == "verdict" || s.Kind == "tune"):
		return s.Key
	}
	return ""
}

// recordFailed answers a store error and says whether there was one.
func recordFailed(w http.ResponseWriter, err error) bool {
	switch {
	case err == nil:
		return false
	case errors.Is(err, store.ErrFull):
		http.Error(w, err.Error(), http.StatusInsufficientStorage)
	case errors.Is(err, store.ErrBadKey):
		http.Error(w, "bad key", http.StatusBadRequest)
	default:
		slog.Error("picks", "error", err)
		http.Error(w, "could not record", http.StatusInternalServerError)
	}
	return true
}
