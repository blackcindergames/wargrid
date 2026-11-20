package main

import (
	"cmp"
	"encoding/json"
	"fmt"
	"math"
	"slices"
	"strings"
)

const (
	maxTuneParams = 12
	maxTuneValue  = 1024
	tuneField     = "tune-value"
)

// TuneParam is one knob of a tune step: a number (min, max, step), a colour (color) or a choice (values).
type TuneParam struct {
	ID     string   `yaml:"id"`
	Label  string   `yaml:"label"`
	Min    *float64 `yaml:"min"`
	Max    *float64 `yaml:"max"`
	Inc    *float64 `yaml:"step"`
	Value  any      `yaml:"value"`
	Color  string   `yaml:"color"`
	Values []string `yaml:"values"`
}

func (p *TuneParam) Kind() string {
	switch {
	case p.Color != "":
		return "color"
	case len(p.Values) > 0:
		return "choice"
	}
	return "number"
}

func asNumber(v any) (float64, bool) {
	switch n := v.(type) {
	case float64:
		return n, !math.IsNaN(n) && !math.IsInf(n, 0)
	case int64:
		return float64(n), true
	case uint64:
		return float64(n), true
	}
	return 0, false
}

// snap puts v on the step grid that starts at Min; false when v is off the grid or outside the range.
func (p *TuneParam) snap(v float64) (float64, bool) {
	lo, hi, step := *p.Min, *p.Max, *p.Inc
	tol := step * 1e-3
	snapped := math.Round((math.Round((v-lo)/step)*step+lo)*1e6) / 1e6
	return snapped, math.Abs(v-snapped) <= tol && snapped >= lo-tol && snapped <= hi+tol
}

func (p *TuneParam) start() any {
	switch p.Kind() {
	case "color":
		return p.Color
	case "choice":
		return p.Value
	}
	n, _ := asNumber(p.Value)
	return n
}

// clean checks one posted or stored value and returns it in its stored form.
func (p *TuneParam) clean(v any) (any, bool) {
	switch p.Kind() {
	case "color":
		c, ok := v.(string)
		return strings.ToLower(c), ok && hexRE.MatchString(c)
	case "choice":
		c, ok := v.(string)
		return c, ok && slices.Contains(p.Values, c)
	}
	n, ok := v.(float64)
	if !ok {
		return nil, false
	}
	return p.snap(n)
}

func (p *TuneParam) problems() []string {
	kinds := 0
	for _, has := range []bool{p.Color != "", len(p.Values) > 0, p.Min != nil || p.Max != nil || p.Inc != nil} {
		if has {
			kinds++
		}
	}
	if kinds != 1 {
		return []string{"needs exactly one of min/max/step, color or values"}
	}
	switch p.Kind() {
	case "color":
		if !hexRE.MatchString(p.Color) || p.Value != nil {
			return []string{"a colour param is color: '#rrggbb' without a value"}
		}
	case "choice":
		if v, ok := p.Value.(string); !ok || !slices.Contains(p.Values, v) || firstDuplicate(p.Values) != "" {
			return []string{"value must be one of values, which must differ"}
		}
	default:
		return p.numberProblems()
	}
	return nil
}

func (p *TuneParam) numberProblems() []string {
	if p.Min == nil || p.Max == nil || p.Inc == nil || *p.Inc <= 0 || *p.Min >= *p.Max {
		return []string{"a number needs min < max and step > 0"}
	}
	v, ok := asNumber(p.Value)
	if !ok {
		return []string{"a number needs a numeric value"}
	}
	if snapped, ok := p.snap(v); !ok || snapped != v {
		return []string{"value must be in range and on the step grid from min"}
	}
	return nil
}

func validateTune(where string, s *Step) []string {
	if s.Kind != "tune" {
		return nil
	}
	var errs []string
	add := func(format string, args ...any) { errs = append(errs, where+": "+fmt.Sprintf(format, args...)) }
	if s.Target == nil || s.Target.Page == "" {
		add("tune needs target.page")
	}
	if n := len(s.Params); n == 0 || n > maxTuneParams {
		add("tune needs 1 to %d params, has %d", maxTuneParams, n)
	}
	got := ids(s.Params, func(p TuneParam) string { return p.ID })
	for i := range s.Params {
		p := &s.Params[i]
		if !idRE.MatchString(p.ID) {
			add("bad param id %q", p.ID)
		}
		for _, e := range p.problems() {
			add("param %s: %s", p.ID, e)
		}
	}
	if d := firstDuplicate(got); d != "" {
		add("param %s appears twice", d)
	}
	return errs
}

// tuneClean accepts a value only when it has exactly the step's params and each is valid; it returns the stored form.
func (s *Step) tuneClean(in map[string]any) (map[string]any, bool) {
	if len(in) != len(s.Params) {
		return nil, false
	}
	out := make(map[string]any, len(in))
	for i := range s.Params {
		p := &s.Params[i]
		v, ok := p.clean(in[p.ID])
		if !ok {
			return nil, false
		}
		out[p.ID] = v
	}
	return out, true
}

// tunedValue is the cleaned `value` field a tuned pick must carry; any other pick carries none.
func (s *Step) tunedValue(pick, raw string) (map[string]any, bool) {
	if s.Kind != "tune" || pick != "tuned" {
		return nil, true
	}
	var in map[string]any
	if len(raw) > maxTuneValue || json.Unmarshal([]byte(raw), &in) != nil {
		return nil, false
	}
	return s.tuneClean(in)
}

// tuneStart is the panel's start: the recorded value when it is still valid, else the step's own.
func (s *Step) tuneStart(e Entry) map[string]any {
	if got, ok := s.tuneClean(e.Value); ok {
		return got
	}
	out := make(map[string]any, len(s.Params))
	for i := range s.Params {
		out[s.Params[i].ID] = s.Params[i].start()
	}
	return out
}

func tuneText(v any) string {
	if n, ok := v.(float64); ok {
		return num(n)
	}
	return fmt.Sprint(v)
}

// tuneLine is the compact summary, in the step's param order: `outline 1.5 · unit 1.2 · you #376eac`.
func (s *Step) tuneLine(value map[string]any) string {
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

func (b *builder) tune(n int, s *Step, record, hint string) TuneView {
	st := b.stage(s)
	e, _ := b.entry(b.round, s.Key)
	start := s.tuneStart(e)
	target := *s.Target
	for i := range s.Params {
		id := s.Params[i].ID
		target.Params = append(slices.Clone(target.Params), kv{id, tuneText(start[id])})
	}
	return TuneView{
		Head: b.head(n, s, record), Info: b.info(st, s, false), Note: b.noteBox(s, hint), Nav: b.nav(n, "Skip"),
		Form: FormView{pickURL(b.round, s, b.carry()), s.chipKey()}, Neutral: s.Neutral,
		Pic:    b.pics(st).pic(picSrc{Render: &target}, s.Crop, "Target", true),
		Params: tuneParamsJSON(s, start), Value: mustJSON(start),
	}
}

// tuneParamsJSON is what <wr-tune> reads: the knobs with their current values.
func tuneParamsJSON(s *Step, start map[string]any) string {
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
