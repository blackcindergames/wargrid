package main

import (
	"cmp"
	"net/url"
	"os"
	"strconv"
	"strings"
)

// The view models: everything the templates print, computed here so the templates hold no logic.

type Chip struct {
	Label, Href, StepKey string
	On, Done, Earlier    bool
}

type HeadView struct {
	Eyebrow, Question string
	ClaudePick        *ClaudePick
	Record            string
}

type ClaudePick struct{ Label, Why string }

type NoteView struct {
	ID, Label, Value, Hint, Post, Sub, Placeholder, What, Chip string
	InForm                                                     bool
}

type NavView struct {
	Prev, Next, NextLabel string
}

type FigureView struct {
	Label string
	Pic   PicView
}

type FoldView struct {
	Label, Text string
	Figures     []FigureView
}

type UseLine struct{ Question, Round, Pick string }

type NumberCell struct {
	Text string
	Low  bool
}

type NumbersRow struct {
	AName, AHex, BName, BHex string
	Contrast, Normal, Deut   NumberCell
	Prot                     NumberCell
}

type InfoView struct {
	// Phone: the folds start closed so the stage is on the first screen.
	Phone     bool
	Why       string
	Look      string
	Ref       *FigureView
	Checklist []string
	Uses      []UseLine
	Numbers   []NumbersRow
	Folds     []FoldView
}

func (i *InfoView) HasCue() bool { return i.Look != "" || i.Ref != nil }
func (i *InfoView) HasInfo() bool {
	return len(i.Checklist) > 0 || len(i.Uses) > 0 || len(i.Numbers) > 0 || len(i.Folds) > 0
}

type builder struct {
	cat     *Catalog
	round   *Round
	entries map[string]Entry
	q       Query
	root    *os.Root
}

func unmark(s string) string { return strings.ReplaceAll(s, "`", "") }

func (b *builder) entry(r *Round, key string) (Entry, bool) {
	e, ok := b.entries[r.Prefix+":"+key]
	return e, ok
}

func (b *builder) pickOf(r *Round, key string) string {
	if e, ok := b.entry(r, key); ok && e.Pick != nil {
		return *e.Pick
	}
	return ""
}

func (b *builder) steps() int { return len(b.round.Loaded) }

func (b *builder) carry() url.Values { return b.q.Carry() }

// stepHref wraps around: before the first step is the summary, after the summary the first step.
func (b *builder) stepHref(n int) string {
	total := b.steps() + 1
	n = ((n-1)%total+total)%total + 1
	if n > b.steps() {
		return summaryURL(b.round, b.carry())
	}
	return stepURL(b.round, n, b.carry())
}

func (b *builder) chips(current int) []Chip {
	var out []Chip
	for i := range b.round.Loaded {
		s := &b.round.Loaded[i]
		key := s.chipKey()
		pick := b.pickOf(b.round, key)
		label := strconv.Itoa(i+1) + " " + s.Key
		if pick != "" {
			label += " · " + pick
		}
		out = append(out, Chip{Label: label, Href: b.stepHref(i + 1), StepKey: key, On: i == current, Done: pick != ""})
	}
	out = append(out, Chip{Label: "Summary", Href: b.stepHref(b.steps() + 1), On: current == b.steps()})
	for _, id := range b.round.Earlier {
		if r := b.cat.Rounds[id]; r != nil {
			out = append(out, Chip{Label: r.Title, Href: summaryURL(r, b.carry()), Earlier: true})
		}
	}
	return out
}

func (b *builder) claudePick(s *Step) *ClaudePick {
	if s.Rec == "" || !s.IsChoice() {
		return nil
	}
	label := "Yes, as drawn"
	if !s.IsConfirm() {
		label = s.Rec + ": " + s.Options[s.Rec].Name
	}
	return &ClaudePick{label, s.RecWhy}
}

func (b *builder) head(n int, s *Step, record string) HeadView {
	h := HeadView{Eyebrow: b.round.Title + " · Step " + strconv.Itoa(n) + " of " + strconv.Itoa(b.steps()), Record: record}
	if s.Question != "" {
		h.Question = s.Question
	} else {
		h.Question = s.Key
	}
	h.ClaudePick = b.claudePick(s)
	return h
}

func (b *builder) nav(n int, nextLabel string) NavView {
	if n >= b.steps() {
		nextLabel = "Summary"
	}
	return NavView{Prev: b.stepHref(n - 1), Next: b.stepHref(n + 1), NextLabel: nextLabel}
}

func (b *builder) stage(s *Step) *Stage { return newStage(b.round, s, b.q.Ctl) }

func (b *builder) pics(st *Stage) picBuilder { return picBuilder{st: st, root: b.root} }

func (b *builder) cropOf(s *Step) *Crop {
	if b.q.Phone && s.PhoneCrop != nil {
		return s.PhoneCrop
	}
	return s.Crop
}

func (b *builder) figures(pb picBuilder, list []Pic, crop *Crop, who string) []FigureView {
	var out []FigureView
	for i := range list {
		e := &list[i]
		out = append(out, FigureView{e.Label, pb.pic(e.src(), crop, who+": "+e.Label, true)})
	}
	return out
}

func (b *builder) folds(pb picBuilder, list []Fold, crop *Crop, who string) []FoldView {
	var out []FoldView
	for _, f := range list {
		out = append(out, FoldView{f.Label, f.Text, b.figures(pb, f.Pics, crop, who)})
	}
	return out
}

func (b *builder) info(st *Stage, s *Step, side bool) InfoView {
	pb := b.pics(st)
	v := InfoView{Phone: b.q.Phone, Why: s.Why, Look: s.Look, Checklist: s.Checklist, Uses: b.uses(s), Numbers: b.numbers(s), Folds: b.folds(pb, s.Folds, s.Crop, "Step")}
	if s.Ref != nil && !side {
		v.Ref = &FigureView{s.Ref.Label, pb.pic(s.Ref.src(), b.cropOf(s), s.Ref.Label, true)}
	}
	return v
}

func (b *builder) numbers(s *Step) []NumbersRow {
	if !b.q.Numbers {
		return nil
	}
	var out []NumbersRow
	for _, p := range s.Pairs {
		n := numbersOf(p.AHex, p.BHex)
		row := NumbersRow{
			AName: p.AName, AHex: p.AHex, BName: p.BName, BHex: p.BHex, Contrast: NumberCell{Text: "–"},
			Normal: cell(n.Normal, minDistance, 1), Deut: cell(n.Deut, minDistance, 1), Prot: cell(n.Prot, minDistance, 1),
		}
		if p.Kind != "vs" {
			row.Contrast = cell(n.Contrast, minContrast, 2)
		}
		out = append(out, row)
	}
	return out
}

func cell(v, bar float64, digits int) NumberCell {
	return NumberCell{Text: strconv.FormatFloat(v, 'f', digits, 64), Low: v < bar}
}

func (b *builder) findUse(ref string) (*Round, *Step) {
	id, key, qualified := strings.Cut(ref, "/")
	if !qualified {
		id, key = b.round.ID, ref
	}
	r := b.cat.Rounds[id]
	if r == nil {
		return nil, nil
	}
	step := r.Step(key)
	return r, step
}

func (b *builder) uses(s *Step) []UseLine {
	var out []UseLine
	for _, ref := range s.Uses {
		r, u := b.findUse(ref)
		if u == nil {
			continue
		}
		shown := "not picked yet, shown with the default"
		if u.Rec != "" {
			shown = "not picked yet, shown with " + pickLabel(u, u.Rec, false)
		}
		if p := b.pickOf(r, u.Key); p != "" {
			shown = pickLabel(u, p, true)
		}
		line := UseLine{Question: u.Question, Pick: shown}
		if line.Question == "" {
			line.Question = u.Key
		}
		if r != b.round {
			line.Round = r.Title
		}
		out = append(out, line)
	}
	return out
}

// pickLabel words a recorded answer the way the summary and the "uses" lines show it.
func pickLabel(s *Step, p string, reveal bool) string {
	if p == "" {
		return ""
	}
	if o, ok := s.Options[p]; ok {
		out := p + ": " + unmark(o.Name)
		if reveal && s.Blind && o.Reveal != "" {
			out += " (" + o.Reveal + ")"
		}
		return out
	}
	switch {
	case p == "neither":
		return cmp.Or(s.Neutral, "Neither")
	case s.Labels != nil && p == "pass" && s.Labels.Pass != "":
		return s.Labels.Pass
	case s.Labels != nil && p == "changes" && s.Labels.Changes != "":
		return s.Labels.Changes
	case s.Verdict != nil && p == "pass" && s.Verdict.Pass != "":
		return s.Verdict.Pass
	case s.Verdict != nil && p == "changes" && s.Verdict.Changes != "":
		return s.Verdict.Changes
	case p == "tuned":
		return "Tuned"
	case p == "yes":
		return "Yes, as drawn"
	case p == "change":
		return "Change"
	}
	return p
}

func (b *builder) note(s *Step, key, id, label string) NoteView {
	e, _ := b.entry(b.round, key)
	return NoteView{ID: id, Label: label, Value: e.Note, Post: noteURL(b.round, s), What: key, Chip: s.chipKey()}
}
