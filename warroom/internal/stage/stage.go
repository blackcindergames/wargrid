package stage

import (
	"cmp"
	"net/url"
	"slices"
	"strconv"
	"strings"
	"wargrid/warroom/internal/rounds"
)

type sizeSpec struct {
	W, H int
	K    float64
}

var sizes = map[string]sizeSpec{
	"1280x720":  {1280, 720, 1},
	"1280x800":  {1280, 800, 1},
	"1920x1080": {1280, 720, 1.5},
	"3440x1440": {1720, 720, 2},
}

// game/scripts/presentation/palette.gd OWNER_BASE and OWNER_BRIGHT.
var ownerSets = map[string][]string{
	"default": {"376eac", "b04a3a", "3f8f4f", "c9a227", "d27a2c", "7a4fa0", "2f9c9c", "c8628f"},
	"neon":    {"2f7bff", "ff2f45", "14d45a", "ffe100", "ff7a00", "a040ff", "00d8e8", "ff4fb0"},
}

const statesPage = "docs/images/hud-v5/source/p2-3a1-states.html"

var defaultRender = rounds.Render{Page: statesPage, W: 1280, H: 720, Hash: "shot={state}&size=720&scale=1"}

// Ctl is one stage control a step offers, resolved from the round's and the step's `controls`.
type Ctl struct {
	Name, Label, Key, Param, Omit string
	Values                        []string
	// Overlay: the HUD control with a list of layers; the app lays the layer over the picture.
	Overlay bool
	nameOf  func(string) string
}

func (c *Ctl) ValueName(v string) string {
	if c.nameOf == nil {
		return v
	}
	return c.nameOf(v)
}

// Cycle is the value dir steps from current, wrapping around.
func (c *Ctl) Cycle(current string, dir int) string {
	i := slices.Index(c.Values, current)
	return c.Values[((i+dir)%len(c.Values)+len(c.Values))%len(c.Values)]
}

func isStaged(s *rounds.Step) bool { return s.Kind == "pictures" || s.Kind == "gallery" }

func ctlOf(name string, spec *rounds.ControlSpec) Ctl {
	def := rounds.ControlDefs[name]
	c := Ctl{Name: name, Label: def.Label, Key: def.Key, Omit: def.Omit, Values: def.Values, nameOf: def.Name}
	switch {
	case name == "hud" && spec.Values != nil:
		c.Values = append([]string{"off"}, spec.Values...)
		c.nameOf = func(v string) string {
			if v == "off" {
				return "Off"
			}
			return "Layer: " + v
		}
		c.Overlay = true
	case spec.Values != nil:
		c.Values = spec.Values
	}
	return c
}

func extraCtl(x *rounds.ExtraControl) Ctl {
	labels := map[string]string{}
	values := make([]string, len(x.Values))
	for i, v := range x.Values {
		values[i] = v.V
		labels[v.V] = v.Label
	}
	c := Ctl{Name: "x-" + x.ID, Label: x.Label, Key: x.Key, Param: x.Param, Values: values}
	if c.Label == "" {
		c.Label = x.ID
	}
	if c.Param == "" {
		c.Param = x.ID
	}
	c.nameOf = func(v string) string {
		if l := labels[v]; l != "" {
			return l
		}
		return v
	}
	return c
}

func buildCtls(round *rounds.Round, s *rounds.Step) []Ctl {
	if !isStaged(s) {
		return nil
	}
	specs, extra := rounds.MergeControls(round.Controls, s.Controls)
	var out []Ctl
	for _, name := range rounds.ControlOrder {
		if spec, ok := specs[name]; ok {
			if c := ctlOf(name, spec); len(c.Values) > 0 {
				out = append(out, c)
			}
		}
	}
	for _, x := range extra {
		if c := extraCtl(&x); len(c.Values) > 0 {
			out = append(out, c)
		}
	}
	return out
}

// Stage is the stage controls of one step with the values one request asked for.
type Stage struct {
	Round *rounds.Round
	Step  *rounds.Step
	Ctls  []Ctl
	raw   map[string]string
}

func NewStage(round *rounds.Round, s *rounds.Step, raw map[string]string) *Stage {
	return &Stage{Round: round, Step: s, Ctls: buildCtls(round, s), raw: raw}
}

func (st *Stage) ctl(name string) *Ctl {
	for i := range st.Ctls {
		if st.Ctls[i].Name == name {
			return &st.Ctls[i]
		}
	}
	return nil
}

// Value is the control's value; one the step does not offer falls back to its first, "" without the control.
func (st *Stage) Value(name string) string {
	c := st.ctl(name)
	switch {
	case c == nil:
		return ""
	case slices.Contains(c.Values, st.raw[name]):
		return st.raw[name]
	}
	return c.Values[0]
}

// Disabled: a game-world backdrop covers the ground colour, so Ground would claim a change the picture does not show.
func (st *Stage) Disabled(name string) bool {
	return name == "ground" && st.Value("world") != "" && st.Value("world") != "plain"
}

func (st *Stage) Base(layers ...*rounds.Render) rounds.Render {
	out := defaultRender
	for _, l := range append([]*rounds.Render{st.Round.Render, st.Step.Render}, layers...) {
		if l != nil {
			overlay(&out, l)
		}
	}
	return out
}

// overlay lets the non-empty fields of top win; a pass map replaces the whole one.
func overlay(r *rounds.Render, top *rounds.Render) {
	if top.Page != "" {
		r.Page = top.Page
	}
	if top.W != 0 {
		r.W = top.W
	}
	if top.H != 0 {
		r.H = top.H
	}
	if top.Hash != "" {
		r.Hash = top.Hash
	}
	if top.Pass != nil {
		r.Pass = top.Pass
	}
	if top.State != "" {
		r.State = top.State
	}
	if top.Crop != nil {
		r.Crop = top.Crop
	}
	if top.Params != nil {
		r.Params = top.Params
	}
}

// Geometry is a render's frame: W x H pixels shown, LW x LH the layout size the page draws at scale K.
type Geometry struct {
	W, H, LW, LH, K float64
}

func (st *Stage) Geometry(r *rounds.Render) Geometry {
	b := st.Base(r)
	w, h := cmp.Or(b.W, 1280), cmp.Or(b.H, 720)
	if b.Pass["size"] == "" || st.ctl("size") == nil {
		return Geometry{float64(w), float64(h), float64(w), float64(h), 1}
	}
	z := sizes[st.Value("size")]
	return Geometry{float64(z.W) * z.K, float64(z.H) * z.K, float64(z.W), float64(z.H), z.K}
}

type Rect struct{ X, Y, W, H float64 }

// CropFor: a crop is drawn for the base frame; on another window size it keeps to the edge it sits nearer, as the HUD does.
func CropFor(c *rounds.Crop, baseW, baseH int, z Geometry) Rect {
	if c == nil {
		return Rect{0, 0, z.W, z.H}
	}
	var dx, dy float64
	if float64(c.X)+float64(c.W)/2 > float64(baseW)/2 {
		dx = z.LW - float64(baseW)
	}
	if float64(c.Y)+float64(c.H)/2 > float64(baseH)/2 {
		dy = z.LH - float64(baseH)
	}
	return Rect{(float64(c.X) + dx) * z.K, (float64(c.Y) + dy) * z.K, float64(c.W) * z.K, float64(c.H) * z.K}
}

func (st *Stage) StateFor(r *rounds.Render) string {
	switch {
	case r != nil && r.State != "":
		return r.State
	case st.Value("state") != "":
		return st.Value("state")
	}
	return "slab"
}

func (st *Stage) ownerHex() string {
	o := st.Value("owner")
	if o == "" || o == "drawn" {
		return ""
	}
	set := st.Value("set")
	if set == "" {
		set = "default"
	}
	i, _ := strconv.Atoi(o)
	return ownerSets[set][i-1]
}

// orderedQuery keeps insertion order like URLSearchParams, which the render pages' hashes are read in.
type orderedQuery []rounds.KV

func parseOrdered(s string) orderedQuery {
	var q orderedQuery
	for _, part := range strings.Split(s, "&") {
		if part == "" {
			continue
		}
		k, v, _ := strings.Cut(part, "=")
		q = append(q, rounds.KV{K: unescape(k), V: unescape(v)})
	}
	return q
}

func unescape(s string) string {
	if u, err := url.QueryUnescape(s); err == nil {
		return u
	}
	return s
}

func (q *orderedQuery) set(k, v string) {
	for i := range *q {
		if (*q)[i].K == k {
			(*q)[i].V = v
			return
		}
	}
	*q = append(*q, rounds.KV{K: k, V: v})
}

// encode is URLSearchParams.toString followed by the page's two readability fixes (comma and colon stay).
func (q orderedQuery) encode() string {
	parts := make([]string, len(q))
	for i, p := range q {
		parts[i] = formEscape(p.K) + "=" + formEscape(p.V)
	}
	out := strings.Join(parts, "&")
	return strings.NewReplacer("%2C", ",", "%3A", ":").Replace(out)
}

// formEscape is URLSearchParams' escaping: unlike url.QueryEscape it keeps * and escapes ~.
func formEscape(s string) string {
	return strings.NewReplacer("%2A", "*", "~", "%7E").Replace(url.QueryEscape(s))
}

// CtlParams is what the controls add to a render page's hash, in control order.
func (st *Stage) CtlParams(r *rounds.Render) orderedQuery {
	pass := st.Base(r).Pass
	var out orderedQuery
	for _, c := range st.Ctls {
		param := c.Param
		if param == "" {
			param = pass[c.Name]
		}
		v := st.Value(c.Name)
		if param == "" || v == c.Omit || c.Overlay {
			continue
		}
		switch c.Name {
		case "size":
			z := sizes[v]
			if z.W != 1280 || z.H != 720 {
				out.set(param, strconv.Itoa(z.W)+"x"+strconv.Itoa(z.H))
			}
			if z.K != 1 {
				out.set("scale", strconv.FormatFloat(z.K, 'f', -1, 64))
			}
		case "owner":
			out.set(param, st.ownerHex())
		case "hud":
			out.set(param, "0")
		default:
			out.set(param, v)
		}
	}
	return out
}

func RepoURL(p string) string {
	if strings.HasPrefix(p, "/") || strings.HasPrefix(p, "http://") || strings.HasPrefix(p, "https://") || strings.HasPrefix(p, "//") {
		return p
	}
	return "/" + p
}

// FrameSrc is the render page's address with its hash: the recipe's, then the option's params, then the controls'.
func (st *Stage) FrameSrc(r *rounds.Render) string {
	b := st.Base(r)
	q := parseOrdered(strings.Replace(b.Hash, "{state}", url.QueryEscape(st.StateFor(r)), 1))
	if r != nil {
		for _, p := range r.Params {
			q.set(p.K, p.V)
		}
	}
	for _, p := range st.CtlParams(r) {
		q.set(p.K, p.V)
	}
	return RepoURL(b.Page) + "#" + q.encode()
}

// HudLayerSrc lays one HUD state over the picture, transparent.
func (st *Stage) HudLayerSrc(z Geometry) string {
	c := st.ctl("hud")
	v := st.Value("hud")
	if c == nil || !c.Overlay || v == "off" {
		return ""
	}
	size := "720"
	if z.LW != 1280 || z.LH != 720 {
		size = strconv.FormatFloat(z.LW, 'f', -1, 64) + "x" + strconv.FormatFloat(z.LH, 'f', -1, 64)
	}
	return RepoURL(statesPage) + "#shot=" + uriComponent(v) + "&size=" + size + "&scale=" + strconv.FormatFloat(z.K, 'f', -1, 64) + "&ground=none"
}

// uriComponent is JS encodeURIComponent, which the prototype's HUD layer address uses.
func uriComponent(s string) string {
	return strings.NewReplacer("+", "%20", "%21", "!", "%27", "'", "%28", "(", "%29", ")", "%2A", "*").Replace(url.QueryEscape(s))
}
