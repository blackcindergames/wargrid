package web

import (
	"cmp"
	"encoding/json"
	"fmt"
	"slices"
	"strings"
	"wargrid/warroom/internal/rounds"
)

const tuneField = "tune-value"

func tuneText(v any) string {
	if n, ok := v.(float64); ok {
		return num(n)
	}
	return fmt.Sprint(v)
}

// tuneLine is the compact summary, in the step's param order: `outline 1.5 · unit 1.2 · you #376eac`.
func tuneLine(s *rounds.Step, value map[string]any) string {
	var parts []string
	for _, p := range s.Params {
		if v, ok := value[p.ID]; ok {
			parts = append(parts, p.ID+" "+tuneText(v))
		}
	}
	return strings.Join(parts, " · ")
}

type TuneView struct {
	Head    HeadView
	Info    InfoView
	Note    NoteView
	Nav     NavView
	Form    FormView
	Pic     PicView
	Params  string
	Value   string
	Neutral string
}

func (b *builder) tune(n int, s *rounds.Step, record, hint string) TuneView {
	st := b.stage(s)
	e, _ := b.entry(b.round, s.Key)
	start := s.TuneStart(e)
	target := *s.Target
	for i := range s.Params {
		id := s.Params[i].ID
		target.Params = append(slices.Clone(target.Params), rounds.KV{K: id, V: tuneText(start[id])})
	}
	return TuneView{
		Head: b.head(n, s, record), Info: b.info(st, s, false), Note: b.noteBox(s, hint), Nav: b.nav(n, "Skip"),
		Form: FormView{pickURL(b.round, s, b.carry()), s.ChipKey()}, Neutral: s.Neutral,
		Pic:    b.pics(st).pic(picSrc{Render: &target}, s.Crop, "Target", true),
		Params: tuneParamsJSON(s, start), Value: mustJSON(start),
	}
}

// tuneParamsJSON is what <wr-tune> reads: the knobs with their current values.
func tuneParamsJSON(s *rounds.Step, start map[string]any) string {
	out := make([]map[string]any, len(s.Params))
	for i := range s.Params {
		p := &s.Params[i]
		m := map[string]any{"id": p.ID, "label": cmp.Or(p.Label, p.ID), "kind": p.Kind(), "value": start[p.ID]}
		switch p.Kind() {
		case "number":
			m["min"], m["max"], m["step"] = *p.Min, *p.Max, *p.Inc
		case "choice":
			m["values"] = p.Values
		}
		out[i] = m
	}
	return mustJSON(out)
}

func mustJSON(v any) string {
	out, err := json.Marshal(v)
	if err != nil {
		panic(err)
	}
	return string(out)
}
