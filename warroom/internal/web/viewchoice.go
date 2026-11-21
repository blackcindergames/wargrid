package web

import (
	"cmp"
	"slices"
	"strconv"
	"strings"
	"wargrid/warroom/internal/rounds"
	"wargrid/warroom/internal/stage"
)

type CardLine struct {
	Text string
	Hl   bool
}

type CardView struct {
	Title, Foot string
	Lines       []CardLine
}

type AudioView struct {
	Letter, URL, Level string
	Missing            bool
}

type OptView struct {
	Letter, Name, Reveal string
	Key                  string
	Picked               bool
	On, Done             bool
	// Measure: the option's measurement slot; a blind step has none until the pick, since numbers could tell the options apart.
	Measure              bool
	Pic                  *PicView
	Card                 *CardView
	Audio                *AudioView
	Sees, Notes, Changes string
	NotesHead            string
	Folds                []FoldView
	Extras               []FigureView
}

// HasAbout leaves out notes: the option's row already shows them.
func (o *OptView) HasAbout() bool {
	return o.Sees != "" || o.Changes != "" || len(o.Folds) > 0
}

type FlipButton struct {
	Letter string
	On     bool
}

type CtlButton struct {
	Name, Label, Key, KeyLabel, Value, Href, BackHref, BackKey string
	Disabled                                                   bool
	Select                                                     *SelectView
}

type SelectView struct {
	Name, Href string
	Options    []SelectOption
}

type SelectOption struct {
	Value, Name string
	Selected    bool
}

type CtlBarView struct {
	Buttons []CtlButton
}

func (c CtlBarView) Status() string {
	var values []string
	for i := range c.Buttons {
		if b := &c.Buttons[i]; b.Name != "numbers" && !b.Disabled {
			values = append(values, b.Value)
		}
	}
	return strings.Join(values, " · ")
}

type ActView struct {
	Confirm bool
	Shown   string
	// Cp is Claude's pick when the page may show it; the Pick button wears a tab while that option is shown.
	Cp      string
	Neutral string
}

type LabView struct {
	Hint, Href, URL string
	Started         bool
	W, H            int
}

type ChoiceView struct {
	Chips               []Chip
	Head                HeadView
	Info                InfoView
	Note                NoteView
	Nav                 NavView
	Side                bool
	Shown               string
	Kind                string
	Flip                []FlipButton
	ViewHref, ViewLabel string
	Ctl                 CtlBarView
	Opts                []OptView
	Lab                 *LabView
	Act                 ActView
	Ref                 *FigureView
	Form                FormView
	// Large: the shown stage has a picture with a large view, so the desktop gets a Large button.
	Large bool
}

// FormView is the answer form the pick buttons submit.
type FormView struct{ Action, Step string }

func (b *builder) shown(s *rounds.Step) string {
	letters := s.OptionLetters()
	pick := b.pickOf(b.round, s.Key)
	// Not Claude's pick: opening on it would anchor the owner on it.
	for _, c := range []string{b.q.Show, pick} {
		if slices.Contains(letters, c) {
			return c
		}
	}
	return letters[0]
}

func (b *builder) side(s *rounds.Step) bool {
	view := cmp.Or(b.q.View, s.View)
	return s.IsChoice() && view == "side" && len(s.Options) > 1
}

func (b *builder) choice(n int, s *rounds.Step, record, hint string) ChoiceView {
	st := b.stage(s)
	side := b.side(s)
	v := ChoiceView{
		Chips: b.chips(n - 1), Head: b.head(n, s, record), Info: b.info(st, s), Nav: b.nav(n, "Skip"), Side: side, Kind: s.Kind,
		Shown: b.shown(s), Form: FormView{pickURL(b.round, s, b.carry()), s.ChipKey()},
	}
	v.Note = b.noteBox(s, hint)
	v.Opts = b.options(st, s, v.Shown)
	v.Ctl = b.ctlBar(n, st, s)
	v.Act = ActView{Confirm: s.IsConfirm(), Shown: v.Shown, Cp: b.rec(s), Neutral: s.Neutral}
	v.Flip = b.flipBar(s, v.Shown)
	v.ViewHref, v.ViewLabel = b.viewToggle(n, s, v.Shown)
	if s.Kind == "lab" {
		v.Lab = b.lab(n, s)
	}
	if s.Ref != nil {
		v.Ref = &FigureView{s.Ref.Label, b.pics(st).pic(picOf(s.Ref), b.cropOf(s), s.Ref.Label, true)}
	}
	v.Large = !side && slices.ContainsFunc(v.Opts, func(o OptView) bool { return o.Pic != nil && o.Pic.Large })
	return v
}

func (b *builder) noteBox(s *rounds.Step, hint string) NoteView {
	label := "Optional note for Claude (saved with your pick)"
	if s.IsConfirm() {
		label = "Note (say what to change, or anything else)"
	}
	n := b.note(s, s.Key, "note", label)
	n.InForm, n.Hint = true, hint
	return n
}

func (b *builder) flipBar(s *rounds.Step, shown string) []FlipButton {
	if s.IsConfirm() {
		return nil
	}
	var out []FlipButton
	for _, l := range s.OptionLetters() {
		out = append(out, FlipButton{l, l == shown})
	}
	return out
}

// flipKey: A to D keep their letters; E to H have only their digits, since F, G and H are stage controls.
func flipKey(letter string) string {
	if letter <= "D" {
		return strings.ToLower(letter)
	}
	return strconv.Itoa(int(letter[0]-'A') + 1)
}

func (b *builder) viewToggle(n int, s *rounds.Step, shown string) (string, string) {
	if len(s.Options) < 2 {
		return "", ""
	}
	q := b.carry()
	q.Set("show", shown)
	if b.side(s) {
		q.Set("view", "flip")
		return stepURL(b.round, n, q), "One at a time"
	}
	q.Set("view", "side")
	return stepURL(b.round, n, q), "Side by side"
}

func (b *builder) lab(n int, s *rounds.Step) *LabView {
	q := b.carry()
	q.Set("lab", "1")
	return &LabView{
		Hint: cmp.Or(s.LabHint, "The lab starts only when you press Start. Click the picture once so it takes the keys."),
		Href: stepURL(b.round, n, q), URL: stage.RepoURL(s.URL), Started: b.q.Lab, W: cmp.Or(s.W, 1280), H: cmp.Or(s.H, 800),
	}
}

func (b *builder) options(st *stage.Stage, s *rounds.Step, shown string) []OptView {
	var out []OptView
	pick := b.pickOf(b.round, s.Key)
	pb := b.pics(st)
	revealed := b.revealed(s)
	for _, l := range s.OptionLetters() {
		o := s.Options[l]
		v := OptView{Letter: l, Key: flipKey(l), Name: cmp.Or(o.Name, l), Picked: pick == l, On: l == shown, Done: l == pick}
		if s.Blind && revealed {
			v.Reveal = o.Reveal
		}
		v.Measure = !s.Blind || revealed
		b.fillBody(&v, pb, s, &o)
		b.fillText(&v, pb, s, &o)
		out = append(out, v)
	}
	return out
}

func hasOption(s *rounds.Step, letter string) bool { _, ok := s.Options[letter]; return ok }

func (b *builder) revealed(s *rounds.Step) bool {
	pick := b.pickOf(b.round, s.Key)
	return pick == "neither" || hasOption(s, pick)
}

// rec is Claude's pick as the page may show it: none on a blind step before the pick, where it would hint at a letter.
func (b *builder) rec(s *rounds.Step) string {
	if s.Blind && !b.revealed(s) {
		return ""
	}
	return s.Rec
}

func (b *builder) fillBody(v *OptView, pb picBuilder, s *rounds.Step, o *rounds.Option) {
	switch s.Kind {
	case "text":
		v.Card = textCard(s, o)
	case "audio":
		v.Audio = &AudioView{v.Letter, stage.RepoURL(o.Audio), o.Level, !pb.served(o.Audio)}
	case "lab":
	default:
		p := pb.pic(optionSrc(o), b.cropOf(s), v.Letter+": "+v.Name, true)
		v.Pic = &p
	}
}

func textCard(s *rounds.Step, o *rounds.Option) *CardView {
	if s.Card == nil {
		return &CardView{Lines: []CardLine{{o.Text, true}}}
	}
	c := &CardView{Title: s.Card.Title, Foot: s.Card.Foot}
	for _, l := range s.Card.Lines {
		if l == nil {
			c.Lines = append(c.Lines, CardLine{o.Text, true})
		} else {
			c.Lines = append(c.Lines, CardLine{*l, false})
		}
	}
	return c
}

func (b *builder) fillText(v *OptView, pb picBuilder, s *rounds.Step, o *rounds.Option) {
	v.Sees, v.Notes, v.Changes = o.Sees, o.Notes, o.Changes
	if o.Sees != "" || s.NotesLabel != "" {
		v.NotesHead = cmp.Or(s.NotesLabel, "Notes")
	}
	crop := s.Crop
	if o.Render != nil && o.Render.Crop != nil {
		crop = o.Render.Crop
	}
	v.Folds = b.folds(pb, o.Folds, crop, v.Letter)
	v.Extras = b.figures(pb, o.Extra, crop, v.Letter)
}

func keyLabel(k string) string { return strings.ToUpper(strings.ReplaceAll(k, "shift+", "⇧")) }

// ctlBar lists the step's controls as links that fetch the same step with the next value.
func (b *builder) ctlBar(n int, st *stage.Stage, s *rounds.Step) CtlBarView {
	var bar CtlBarView
	for i := range st.Ctls {
		bar.Buttons = append(bar.Buttons, b.ctlButton(n, st, &st.Ctls[i]))
	}
	if len(s.Pairs) > 0 {
		q := b.carry()
		state := "shown"
		if b.q.Numbers {
			q.Set("numbers", "0")
		} else {
			q.Del("numbers")
			state = "hidden"
		}
		bar.Buttons = append(bar.Buttons, CtlButton{Name: "numbers", Label: "Numbers", Key: "k", KeyLabel: "K", Value: state, Href: stepURL(b.round, n, q)})
	}
	return bar
}

func (b *builder) ctlButton(n int, st *stage.Stage, c *stage.Ctl) CtlButton {
	cur := st.Value(c.Name)
	btn := CtlButton{Name: c.Name, Label: c.Label, Key: c.Key, Value: c.ValueName(cur)}
	if c.Key != "" {
		btn.KeyLabel = keyLabel(c.Key)
	}
	if st.Disabled(c.Name) {
		btn.Disabled, btn.Value = true, "n/a with a backdrop"
		return btn
	}
	href := func(v string) string { return stepURL(b.round, n, b.q.WithCtl(c.Name, v, c.Values[0])) }
	if len(c.Values) > 4 {
		btn.Select = b.selectOf(c, cur, n)
	}
	if len(c.Values) > 1 {
		btn.Href = href(c.Cycle(cur, 1))
	}
	if back, ok := map[string]string{"state": "p", "heading": "shift+r"}[c.Name]; ok {
		btn.BackKey, btn.BackHref = back, href(c.Cycle(cur, -1))
	}
	return btn
}

func (b *builder) selectOf(c *stage.Ctl, cur string, n int) *SelectView {
	q := b.q.WithCtl(c.Name, c.Values[0], c.Values[0])
	sel := &SelectView{Name: c.Name, Href: stepURL(b.round, n, q)}
	for _, v := range c.Values {
		sel.Options = append(sel.Options, SelectOption{v, c.ValueName(v), v == cur})
	}
	return sel
}

// maxCols: past four options side by side the pictures get too small, so the grid wraps; the reference tile comes on top.
const maxCols = 4

func (v *ChoiceView) Cols() int {
	if v.Ref != nil {
		return min(len(v.Opts), maxCols) + 1
	}
	return min(len(v.Opts), maxCols)
}
