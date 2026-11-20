package rounds

import (
	"errors"
	"slices"
	"strconv"
	"strings"
)

// ControlSpec is one stage control a step turns on: `true` (every value, Values nil) or a list.
type ControlSpec struct {
	Values []string
}

func (c *ControlSpec) UnmarshalYAML(decode func(any) error) error {
	var on bool
	if decode(&on) == nil {
		if !on {
			return errors.New("write true or a list of values, or remove the control")
		}
		return nil
	}
	return decode(&c.Values)
}

type ExtraValue struct {
	V     string `yaml:"v"`
	Label string `yaml:"label"`
}

// ExtraControl is a step's own control, sent to the render page as Param (default ID).
type ExtraControl struct {
	ID     string       `yaml:"id"`
	Label  string       `yaml:"label"`
	Key    string       `yaml:"key"`
	Param  string       `yaml:"param"`
	Values []ExtraValue `yaml:"values"`
}

// Controls is the field set of round and step `controls`; strict decoding rejects an unknown control name.
type Controls struct {
	Size    *ControlSpec   `yaml:"size"`
	Fit     *ControlSpec   `yaml:"fit"`
	Ground  *ControlSpec   `yaml:"ground"`
	World   *ControlSpec   `yaml:"world"`
	Zoom    *ControlSpec   `yaml:"zoom"`
	Hud     *ControlSpec   `yaml:"hud"`
	State   *ControlSpec   `yaml:"state"`
	Tier    *ControlSpec   `yaml:"tier"`
	Owner   *ControlSpec   `yaml:"owner"`
	Set     *ControlSpec   `yaml:"set"`
	Heading *ControlSpec   `yaml:"heading"`
	Cvd     *ControlSpec   `yaml:"cvd"`
	Marker  *ControlSpec   `yaml:"marker"`
	Extra   []ExtraControl `yaml:"extra"`
}

// ControlDef is what the app knows about one stage control.
type ControlDef struct {
	Key    string
	Label  string
	Values []string
	// Omit: the value that sends nothing to the render page.
	Omit string
	// App: the app does it itself, so the render page needs no `render.pass` entry.
	App bool
	// Name shows a value; nil shows the value itself.
	Name func(string) string
}

// SizeOrder lists the window sizes; the stage package holds their geometry.
var SizeOrder = []string{"1280x720", "1280x800", "1920x1080", "3440x1440"}

var ControlOrder = []string{"size", "fit", "ground", "world", "zoom", "hud", "state", "tier", "owner", "set", "heading", "cvd", "marker"}

var ControlDefs = map[string]ControlDef{
	"size":    {Key: "s", Label: "Window", Values: SizeOrder, Omit: "1280x720", Name: sizeName},
	"fit":     {Key: "f", Label: "Scale", Values: []string{"fit", "100"}, App: true, Name: func(v string) string { return map[string]string{"fit": "Fit", "100": "True 100 %"}[v] }},
	"ground":  {Key: "g", Label: "Ground", Values: []string{"sand", "dark"}, Name: capitalise},
	"world":   {Key: "shift+g", Label: "Backdrop", Values: []string{"plain", "none", "one", "many", "factory", "plant", "builder", "build", "place", "blocked", "enemy", "pile", "site"}, Omit: "plain", Name: worldName},
	"zoom":    {Key: "z", Label: "Zoom", Values: []string{"0.5", "1", "2"}},
	"hud":     {Key: "h", Label: "HUD", Values: []string{"on", "off"}, Omit: "on", Name: capitalise},
	"state":   {Key: "n", Label: "State"},
	"tier":    {Key: "t", Label: "Tier", Values: []string{"full", "core"}, Name: capitalise},
	"owner":   {Key: "o", Label: "Owner", Values: []string{"drawn", "1", "2", "3", "4", "5", "6", "7", "8"}, Omit: "drawn", Name: ownerName},
	"set":     {Key: "shift+o", Label: "Colours", Values: []string{"default", "neon"}, App: true, Name: capitalise},
	"heading": {Key: "r", Label: "Heading", Values: []string{"0", "1", "2", "3", "4", "5", "6", "7"}, Name: headingName},
	"cvd": {Key: "shift+c", Label: "Colour vision", Values: []string{"normal", "deut", "prot"}, App: true, Name: func(v string) string {
		return map[string]string{"normal": "Normal", "deut": "Deuteranopia", "prot": "Protanopia"}[v]
	}},
	"marker": {Key: "m", Label: "Marker", Values: []string{"on", "off"}, App: true, Name: capitalise},
}

func sizeName(v string) string { return strings.Replace(v, "x", " x ", 1) }

func capitalise(v string) string {
	if v == "" {
		return v
	}
	return strings.ToUpper(v[:1]) + v[1:]
}

func worldName(v string) string {
	if v == "plain" {
		return "Plain ground"
	}
	return "World: " + v
}

func ownerName(v string) string {
	if v == "drawn" {
		return "As drawn"
	}
	return "P" + v
}

func headingName(v string) string {
	n, _ := strconv.Atoi(v)
	return strconv.Itoa(n*45) + "°"
}

var fixedAppKeys = []string{"a", "b", "c", "d", "1", "2", "3", "4", "w", "enter", "arrowleft", "arrowright", "[", "]", "backspace", "n", "p", "l", " ", "?", "k", "shift+r"}

func appKey(k string) bool {
	if slices.Contains(fixedAppKeys, k) {
		return true
	}
	for _, d := range ControlDefs {
		if d.Key == k {
			return true
		}
	}
	return false
}

func (c *Controls) specs() map[string]*ControlSpec {
	if c == nil {
		return nil
	}
	all := map[string]*ControlSpec{
		"size": c.Size, "fit": c.Fit, "ground": c.Ground, "world": c.World, "zoom": c.Zoom, "hud": c.Hud, "state": c.State,
		"tier": c.Tier, "owner": c.Owner, "set": c.Set, "heading": c.Heading, "cvd": c.Cvd, "marker": c.Marker,
	}
	for name, spec := range all {
		if spec == nil {
			delete(all, name)
		}
	}
	return all
}

// MergeControls lets a step's controls override the round's, per control; a step's `extra` replaces the round's.
func MergeControls(round, step *Controls) (map[string]*ControlSpec, []ExtraControl) {
	specs := round.specs()
	if specs == nil {
		specs = map[string]*ControlSpec{}
	}
	for name, spec := range step.specs() {
		specs[name] = spec
	}
	switch {
	case step != nil && step.Extra != nil:
		return specs, step.Extra
	case round != nil:
		return specs, round.Extra
	}
	return specs, nil
}

func validateControls(where string, round *Round, s *Step) []string {
	specs, extra := MergeControls(round.Controls, s.Controls)
	pass := round.Render.passMap()
	if s.Render != nil && s.Render.Pass != nil {
		pass = s.Render.Pass
	}
	var errs []string
	for _, name := range ControlOrder {
		spec, ok := specs[name]
		if !ok {
			continue
		}
		errs = append(errs, validateSpec(where, name, spec, specs, pass)...)
	}
	for _, x := range extra {
		if x.ID == "" || len(x.Values) == 0 {
			errs = append(errs, where+": extra control needs id and values")
		}
		if x.Key != "" && appKey(x.Key) {
			errs = append(errs, where+": extra control "+x.ID+" key "+x.Key+" is taken by the app")
		}
	}
	return errs
}

func validateSpec(where, name string, spec *ControlSpec, specs map[string]*ControlSpec, pass map[string]string) []string {
	def := ControlDefs[name]
	var errs []string
	hudLayers := name == "hud" && spec.Values != nil
	used := def.App || pass[name] != "" || name == "state" || hudLayers || (name == "set" && specs["owner"] != nil)
	if !used {
		errs = append(errs, where+": control "+name+" does nothing here (the render page does not take it: render.pass."+name+")")
	}
	if name == "state" && len(spec.Values) == 0 {
		errs = append(errs, where+": control state needs a list of states")
	}
	if name == "hud" || len(def.Values) == 0 {
		return errs
	}
	for _, v := range spec.Values {
		if !slices.Contains(def.Values, v) {
			errs = append(errs, where+": control "+name+" has no value "+v)
		}
	}
	return errs
}
