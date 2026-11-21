package web

import (
	"bytes"
	"cmp"
	"context"
	"log/slog"
	"net/http"
	"wargrid/warroom/internal/rounds"

	"github.com/a-h/templ"
)

// htmx asks for #page's inside with this request type; a full page, history restore included, gets the document.
func wantsFragment(r *http.Request) bool {
	return r.Header.Get("HX-Request-Type") == "partial"
}

func respond(w http.ResponseWriter, r *http.Request, title string, p *PageView) {
	page := Document(title, *p)
	if wantsFragment(r) {
		page = Fragment(title, *p)
	}
	render(w, r.WithContext(context.WithValue(r.Context(), readOnlyKey{}, p.ReadOnly)), page)
}

func render(w http.ResponseWriter, r *http.Request, page templ.Component) {
	var out bytes.Buffer
	if err := page.Render(r.Context(), &out); err != nil {
		slog.Error("render", "error", err)
		http.Error(w, "render failed", http.StatusInternalServerError)
		return
	}
	h := w.Header()
	h.Set("Content-Type", "text/html; charset=utf-8")
	h.Set("Cache-Control", "no-store")
	h.Add("Vary", "HX-Request-Type")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(out.Bytes())
}

func (b *builder) stepBody(n int, s *rounds.Step, record, hint string) (templ.Component, *PhoneView) {
	plain := b.phoneBase(n, CtlBarView{})
	chips := b.chips(n - 1)
	switch s.Kind {
	case rounds.KindMissing:
		return MissingMain(b.missing(n, s), chips), &plain
	case "gallery":
		v := b.gallery(n, s, record)
		return GalleryMain(v, chips), b.galleryPhone(n, &v)
	case "verdict":
		plain.Note = true
		return VerdictMain(b.verdictStep(n, s, record), chips), &plain
	case "wording":
		plain.Note = true
		return WordingMain(b.wording(n, s, record), chips), &plain
	case "tune":
		plain.Note, plain.Tuned, plain.Neutral = true, true, s.Neutral
		return TuneMain(b.tune(n, s, record, hint), chips), &plain
	}
	v := b.choice(n, s, record, hint)
	return ChoiceMain(v), b.choicePhone(n, s, &v)
}

func (b *builder) stepPageView(errs []string, n int, record, hint string) *PageView {
	s := &b.round.Loaded[n-1]
	st := b.stage(s)
	cvd := cmp.Or(st.Value("cvd"), "normal")
	body, phone := b.stepBody(n, s, record, hint)
	if b.readOnly {
		phone.Pick, phone.Confirm, phone.Tuned, phone.Neutral, phone.Note = false, false, false, "", false
	}
	return &PageView{
		ReadOnly: b.readOnly, Errors: errs, Cvd: cvd, True100: st.Value("fit") == "100", Body: body,
		Phone: phone, Legend: legendOf(st, len(s.Pairs) > 0), Keys: b.q.Keys,
	}
}

func (b *builder) summaryPageView(errs []string) *PageView {
	steps := b.steps()
	nav := NavView{Prev: b.stepHref(steps), Next: b.stepHref(1), NextLabel: "Step 1"}
	body := SummaryMain(b.summary(), nav, b.chips(steps))
	phone := PhoneView{Prev: nav.Prev, Next: nav.Next, Copy: true}
	return &PageView{ReadOnly: b.readOnly, Errors: errs, Cvd: "normal", Body: body, Phone: &phone, Legend: legendOf(nil, false), Keys: b.q.Keys}
}

// shotView is the shown option (gallery: item) alone, whole unless crop=step asks for the step's crop.
func (b *builder) shotView(s *rounds.Step) ShotView {
	st := b.stage(s)
	v := ShotView{Cvd: cmp.Or(st.Value("cvd"), "normal"), Pic: PicView{Kind: "none"}}
	var src picSrc
	switch {
	case s.Kind == "gallery" && len(s.Items) > 0:
		src = itemSrc(&s.Items[b.itemIndex(s)])
	case s.IsChoice() && s.Kind != "lab":
		o := s.Options[b.shown(s)]
		src = optionSrc(&o)
	default:
		return v
	}
	var crop *rounds.Crop
	if src.Render != nil {
		r := *src.Render
		if b.q.Crop == "step" {
			crop = s.Crop
		} else {
			r.Crop = nil
		}
		src.Render = &r
	}
	v.Pic = b.pics(st).pic(src, crop, "shot", true)
	v.Pic.Whole = nil
	return v
}

type readOnlyKey struct{}

// isReadOnly lets any template leave out the pick and note controls without threading a flag through every view model.
func isReadOnly(ctx context.Context) bool {
	ro, _ := ctx.Value(readOnlyKey{}).(bool)
	return ro
}
