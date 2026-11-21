package web

import (
	"cmp"
	"strings"
	"wargrid/warroom/internal/rounds"
	"wargrid/warroom/internal/stage"
)

// PhoneView is the bar at the bottom of a phone-sized page: two rows of buttons and the Controls sheet.
type PhoneView struct {
	Prev, Next          string
	Flip                []FlipButton
	Shown, Cp           string
	Pick, Confirm       bool
	Tuned               bool
	Neutral             string
	ViewHref, ViewLabel string
	Play, Note, Copy    bool
	ItemPrev, ItemNext  string
	Whole               bool
	Ctl                 CtlBarView
}

// maxFlipInRow: more option buttons than this get their own rows, so each stays a thumb wide.
const maxFlipInRow = 4

func (p *PhoneView) FlipRow() bool { return len(p.Flip) > maxFlipInRow }

type LegendRow struct {
	Keys, Text string
	Off        bool
}

type LegendView struct {
	Keys, Controls []LegendRow
}

var legendKeys = []LegendRow{
	{"A B C D or 1 to 8", "show that option (E to H: 5 to 8 only; side by side: select it, or click its tile)", false},
	{"0", "show Today, the picture as it is now (only to look: Pick waits until you show an option)", false},
	{"Enter", "pick the shown option, record it and go on", false},
	{"W", "one at a time / side by side", false},
	{"← → (or [ ], Backspace)", "previous / next step without picking", false},
	{"N P", "next / previous item inside a step (gallery, or the state)", false},
	{"L or click a picture", "large view", false},
	{"Space", "play / stop the shown option's sound (nothing plays on its own)", false},
	{"Esc", "close the large view or this list", false},
	{"?", "this list", false},
	{"", "Keys do nothing while you type in a note. On a phone: the buttons at the bottom (Controls: side by side, the neutral answer, the stage controls, Whole screen and this list); tap the picture to zoom (side by side, the first tap on another tile selects it), swipe it to flip.", false},
}

const maxLegendValues = 4

func ctlLegendText(def *rounds.ControlDef) string {
	label := strings.ToLower(def.Label) + ": "
	if len(def.Values) == 0 {
		return label + "next / previous"
	}
	var names []string
	for _, v := range def.Values[:min(maxLegendValues, len(def.Values))] {
		if def.Name != nil {
			v = def.Name(v)
		}
		names = append(names, v)
	}
	text := label + strings.Join(names, " / ")
	if len(def.Values) > maxLegendValues {
		text += " ..."
	}
	return text
}

// legendOf lists every stage control with whether this step has it; st is nil off a step page.
func legendOf(st *stage.Stage, pairs bool) LegendView {
	on := map[string]*stage.Ctl{}
	if st != nil {
		for i := range st.Ctls {
			on[st.Ctls[i].Name] = &st.Ctls[i]
		}
	}
	v := LegendView{Keys: legendKeys}
	suffix := map[string]string{"state": " P", "heading": " ⇧R"}
	for _, name := range rounds.ControlOrder {
		def := rounds.ControlDefs[name]
		_, has := on[name]
		v.Controls = append(v.Controls, LegendRow{keyLabel(def.Key) + suffix[name], ctlLegendText(&def), !has})
	}
	v.Controls = append(v.Controls, LegendRow{"K", "numbers panel (contrast, colour distance)", !pairs})
	if st != nil {
		for i := range st.Ctls {
			if c := &st.Ctls[i]; strings.HasPrefix(c.Name, "x-") {
				v.Controls = append(v.Controls, LegendRow{cmp.Or(keyLabel(c.Key), "(button)"), c.Label + " (this step)", false})
			}
		}
	}
	return v
}

func (b *builder) phoneBase(n int, ctl CtlBarView) PhoneView {
	return PhoneView{Prev: b.stepHref(n - 1), Next: b.stepHref(n + 1), Ctl: ctl}
}

func (b *builder) choicePhone(n int, s *rounds.Step, v *ChoiceView) *PhoneView {
	p := b.phoneBase(n, v.Ctl)
	p.Flip, p.Shown, p.Cp, p.Confirm, p.Pick = v.Flip, v.Shown, v.Act.Cp, v.Act.Confirm, !v.Act.Confirm
	p.Neutral, p.Play, p.Note = s.Neutral, s.Kind == "audio", true
	if len(s.Options) > 1 {
		p.ViewHref, p.ViewLabel = v.ViewHref, "Side"
		if v.Side {
			p.ViewLabel = "One"
		}
	}
	p.Whole = s.Kind == "pictures" && s.Crop != nil && b.hasStill(s)
	return &p
}

func (b *builder) hasStill(s *rounds.Step) bool {
	for l := range s.Options {
		if s.Options[l].Video == "" {
			return true
		}
	}
	return false
}

func (b *builder) galleryPhone(n int, v *GalleryView) *PhoneView {
	p := b.phoneBase(n, v.Ctl)
	p.Note, p.ItemPrev, p.ItemNext = !v.Empty, v.PrevHref, v.NextHref
	return &p
}
