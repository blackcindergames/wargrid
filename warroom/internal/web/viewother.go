package web

import (
	"cmp"
	"sort"
	"strconv"
	"strings"
	"wargrid/warroom/internal/rounds"
	"wargrid/warroom/internal/store"
)

type ThumbView struct {
	Label, Href string
	On, Noted   bool
	Pic         PicView
}

type VerdictButton struct {
	Value, Label string
	Done         bool
}

type VerdictView struct {
	Buttons []VerdictButton
	Note    NoteView
}

type GalleryView struct {
	Head      HeadView
	Info      InfoView
	Nav       NavView
	Ctl       CtlBarView
	Count     string
	ItemLabel string
	Caption   string
	ItemNote  NoteView
	Main      PicView
	Thumbs    []ThumbView
	PrevHref  string
	NextHref  string
	Verdict   *VerdictView
	Form      FormView
	Empty     bool
}

type FieldView struct {
	Note NoteView
	Was  string
}

type WordingView struct {
	Head   HeadView
	Info   InfoView
	Nav    NavView
	Fields []FieldView
}

type VerdictStepView struct {
	Head    HeadView
	Info    InfoView
	Nav     NavView
	Verdict VerdictView
	Form    FormView
}

type MissingView struct {
	Eyebrow, Key, Path string
	Nav                NavView
}

func (b *builder) itemIndex(s *rounds.Step) int {
	for i, it := range s.Items {
		if it.ID == b.q.Item {
			return i
		}
	}
	return 0
}

func (b *builder) gallery(n int, s *rounds.Step, record string) GalleryView {
	st := b.stage(s)
	v := GalleryView{Head: b.head(n, s, record), Info: b.info(st, s, false), Nav: b.nav(n, "Skip"), Ctl: b.ctlBar(n, st, s), Form: FormView{pickURL(b.round, s, b.carry()), s.ChipKey()}}
	if len(s.Items) == 0 {
		v.Empty = true
		return v
	}
	i := b.itemIndex(s)
	it := &s.Items[i]
	pb := b.pics(st)
	v.Count = strconv.Itoa(i+1) + " of " + strconv.Itoa(len(s.Items))
	v.ItemLabel, v.Caption = cmp.Or(it.Label, it.ID), it.Caption
	v.ItemNote = b.note(s, s.Key+":"+it.ID, "lnote", "Note on this one (optional)")
	v.ItemNote.Sub = it.ID
	v.Main = pb.pic(itemSrc(it), nil, cmp.Or(it.Label, it.ID), true)
	v.PrevHref, v.NextHref = b.itemHref(n, s, i-1), b.itemHref(n, s, i+1)
	for j := range s.Items {
		t := &s.Items[j]
		e, _ := b.entry(b.round, s.Key+":"+t.ID)
		v.Thumbs = append(v.Thumbs, ThumbView{cmp.Or(t.Label, t.ID), b.itemHref(n, s, j), j == i, strings.TrimSpace(e.Note) != "", pb.pic(itemSrc(t), nil, t.Label, false)})
	}
	if s.Verdict != nil {
		vv := b.verdictBox(s, s.VerdictKey(), s.Verdict.Pass, s.Verdict.Changes)
		v.Verdict = &vv
	}
	return v
}

func (b *builder) itemHref(n int, s *rounds.Step, i int) string {
	count := len(s.Items)
	q := b.carry()
	q.Set("item", s.Items[((i%count)+count)%count].ID)
	return stepURL(b.round, n, q)
}

func (b *builder) verdictBox(s *rounds.Step, key, pass, changes string) VerdictView {
	got := b.pickOf(b.round, key)
	n := b.note(s, key, "vnote", "")
	n.InForm, n.Placeholder = true, "Optional overall note (saved with the verdict)"
	return VerdictView{
		Buttons: []VerdictButton{{"pass", pass, got == "pass"}, {"changes", changes, got == "changes"}},
		Note:    n,
	}
}

func (b *builder) verdictStep(n int, s *rounds.Step, record string) VerdictStepView {
	st := b.stage(s)
	labels := rounds.Labels{Pass: "Pass", Changes: "Changes needed"}
	if s.Labels != nil {
		labels = *s.Labels
	}
	return VerdictStepView{
		Head: b.head(n, s, record), Info: b.info(st, s, false), Nav: b.nav(n, "Skip"),
		Verdict: b.verdictBox(s, s.Key, labels.Pass, labels.Changes), Form: FormView{pickURL(b.round, s, b.carry()), s.ChipKey()},
	}
}

func (b *builder) wording(n int, s *rounds.Step, record string) WordingView {
	st := b.stage(s)
	v := WordingView{Head: b.head(n, s, record), Info: b.info(st, s, false), Nav: b.nav(n, "Done, next")}
	for _, f := range s.Fields {
		key := s.Key + ":" + f.ID
		note := b.note(s, key, "f-"+f.ID, cmp.Or(f.Label, f.ID))
		if _, saved := b.entry(b.round, key); !saved {
			note.Value = f.Text
		}
		note.Sub = f.ID
		v.Fields = append(v.Fields, FieldView{note, f.Text})
	}
	return v
}

func (b *builder) missing(n int, s *rounds.Step) MissingView {
	return MissingView{Eyebrow: "Step " + strconv.Itoa(n) + " of " + strconv.Itoa(b.steps()), Key: s.Key, Path: "rounds/" + b.round.ID + "/" + s.Key + ".yaml", Nav: b.nav(n, "Skip")}
}

// ---------- summary ----------

type SumRow struct{ Label, Pick, Note string }

type SumSection struct {
	Title, Count string
	Rows         []SumRow
}

type SumLink struct{ Label, Href string }

type SummaryView struct {
	Eyebrow, Title string
	Main           SumSection
	Open           []SumLink
	Earlier        []SumSection
	Text           string
}

func asked(r *rounds.Round) []*rounds.Step {
	var out []*rounds.Step
	for i := range r.Loaded {
		if s := &r.Loaded[i]; s.AnswerKey() != "" {
			out = append(out, s)
		}
	}
	return out
}

func (b *builder) unanswered(r *rounds.Round) []*rounds.Step {
	var out []*rounds.Step
	for _, i := range r.Open(b.entries) {
		out = append(out, &r.Loaded[i])
	}
	return out
}

func (b *builder) answered(r *rounds.Round) string {
	total := len(asked(r))
	return strconv.Itoa(total-len(b.unanswered(r))) + " of " + strconv.Itoa(total) + " answered"
}

type orderedRow struct {
	SumRow
	order float64
}

func (b *builder) rowOf(r *rounds.Round, local string, e store.Entry) orderedRow {
	k, sub, _ := strings.Cut(local, ":")
	for i := range r.Loaded {
		if g := &r.Loaded[i]; g.Kind == "gallery" && g.Verdict != nil && g.VerdictKey() == local {
			return orderedRow{SumRow{"Verdict", pickLabel(g, deref(e.Pick), true), e.Note}, float64(i) + 0.9}
		}
	}
	s := r.Step(k)
	if s == nil {
		return orderedRow{SumRow{local, pickLabel(&rounds.Step{}, deref(e.Pick), true), e.Note}, 999}
	}
	order := float64(indexOfStep(r, k))
	label := cmp.Or(s.Question, k)
	if sub != "" {
		order += 0.5
		label = subLabel(s, label, sub)
	}
	pick := pickLabel(s, deref(e.Pick), true)
	if s.Kind == "tune" && len(e.Value) > 0 {
		pick = tuneLine(s, e.Value)
	}
	return orderedRow{SumRow{label, pick, e.Note}, order}
}

func subLabel(s *rounds.Step, question, sub string) string {
	for _, it := range s.Items {
		if it.ID == sub {
			return "Note on " + cmp.Or(it.Label, sub)
		}
	}
	for _, f := range s.Fields {
		if f.ID == sub {
			return question + ": " + cmp.Or(f.Label, sub)
		}
	}
	return "Note on " + sub
}

func indexOfStep(r *rounds.Round, key string) int {
	for i := range r.Loaded {
		if r.Loaded[i].Key == key {
			return i
		}
	}
	return -1
}

func deref(p *string) string {
	if p == nil {
		return ""
	}
	return *p
}

func (b *builder) section(r *rounds.Round) SumSection {
	var rows []orderedRow
	for key, e := range b.entries {
		if local, ok := strings.CutPrefix(key, r.Prefix+":"); ok {
			rows = append(rows, b.rowOf(r, local, e))
		}
	}
	sort.SliceStable(rows, func(i, j int) bool {
		if rows[i].order != rows[j].order {
			return rows[i].order < rows[j].order
		}
		return rows[i].Label < rows[j].Label
	})
	sec := SumSection{Title: r.Title, Count: b.answered(r)}
	for _, row := range rows {
		sec.Rows = append(sec.Rows, row.SumRow)
	}
	return sec
}

func (b *builder) summary() SummaryView {
	v := SummaryView{Eyebrow: b.round.Title + " · Summary", Title: "What the server recorded", Main: b.section(b.round)}
	for _, s := range b.unanswered(b.round) {
		v.Open = append(v.Open, SumLink{s.Key, b.stepHref(indexOfStep(b.round, s.Key) + 1)})
	}
	sections := []SumSection{v.Main}
	for _, id := range b.round.Earlier {
		if r := b.cat.Rounds[id]; r != nil {
			sec := b.section(r)
			v.Earlier = append(v.Earlier, sec)
			sections = append(sections, sec)
		}
	}
	v.Text = summaryText(sections)
	return v
}

func summaryText(sections []SumSection) string {
	var parts []string
	for _, sec := range sections {
		lines := []string{sec.Title + " (" + sec.Count + ")"}
		for _, r := range sec.Rows {
			pick := cmp.Or(r.Pick, "(note)")
			line := "- " + unmark(r.Label) + ": " + pick
			if r.Note != "" {
				line += " | " + r.Note
			}
			lines = append(lines, line)
		}
		parts = append(parts, strings.Join(lines, "\n"))
	}
	return strings.Join(parts, "\n\n")
}

// ---------- round list ----------

type RoundLink struct{ Title, Href string }

func roundLinks(c *rounds.Catalog, showDemo bool) []RoundLink {
	var out []RoundLink
	for _, e := range c.Index {
		if r := c.Rounds[e.ID]; r != nil && (showDemo || !e.Demo) {
			out = append(out, RoundLink{cmp.Or(e.Title, e.ID), "/r/" + r.ID})
		}
	}
	return out
}
