package main

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

type controlDef struct {
	key    string
	label  string
	values []string
	// omit: the value that sends nothing to the render page.
	omit string
	// app: the app does it itself, so the render page needs no `render.pass` entry.
	app bool
	// name shows a value; nil shows the value itself.
	name func(string) string
}

var controlOrder = []string{"size", "fit", "ground", "world", "zoom", "hud", "state", "tier", "owner", "set", "heading", "cvd", "marker"}

var controlDefs = map[string]controlDef{
	"size":    {key: "s", label: "Window", values: sizeOrder, omit: "1280x720", name: func(v string) string { return sizes[v].Label }},
	"fit":     {key: "f", label: "Scale", values: []string{"fit", "100"}, app: true, name: func(v string) string { return map[string]string{"fit": "Fit", "100": "True 100 %"}[v] }},
	"ground":  {key: "g", label: "Ground", values: []string{"sand", "dark"}, name: capitalise},
	"world":   {key: "shift+g", label: "Backdrop", values: []string{"plain", "none", "one", "many", "factory", "plant", "builder", "build", "place", "blocked", "enemy", "pile", "site"}, omit: "plain", name: worldName},
	"zoom":    {key: "z", label: "Zoom", values: []string{"0.5", "1", "2"}},
	"hud":     {key: "h", label: "HUD", values: []string{"on", "off"}, omit: "on", name: capitalise},
	"state":   {key: "n", label: "State"},
	"tier":    {key: "t", label: "Tier", values: []string{"full", "core"}, name: capitalise},
	"owner":   {key: "o", label: "Owner", values: []string{"drawn", "1", "2", "3", "4", "5", "6", "7", "8"}, omit: "drawn", name: ownerName},
	"set":     {key: "shift+o", label: "Colours", values: []string{"default", "neon"}, app: true, name: capitalise},
	"heading": {key: "r", label: "Heading", values: []string{"0", "1", "2", "3", "4", "5", "6", "7"}, name: headingName},
	"cvd": {key: "shift+c", label: "Colour vision", values: []string{"normal", "deut", "prot"}, app: true, name: func(v string) string {
		return map[string]string{"normal": "Normal", "deut": "Deuteranopia", "prot": "Protanopia"}[v]
	}},
	"marker": {key: "m", label: "Marker", values: []string{"on", "off"}, app: true, name: capitalise},
}

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
	for _, d := range controlDefs {
		if d.key == k {
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

// mergeControls lets a step's controls override the round's, per control; a step's `extra` replaces the round's.
func mergeControls(round, step *Controls) (map[string]*ControlSpec, []ExtraControl) {
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
	specs, extra := mergeControls(round.Controls, s.Controls)
	pass := round.Render.passMap()
	if s.Render != nil && s.Render.Pass != nil {
		pass = s.Render.Pass
	}
	var errs []string
	for _, name := range controlOrder {
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
	def := controlDefs[name]
	var errs []string
	hudLayers := name == "hud" && spec.Values != nil
	used := def.app || pass[name] != "" || name == "state" || hudLayers || (name == "set" && specs["owner"] != nil)
	if !used {
		errs = append(errs, where+": control "+name+" does nothing here (the render page does not take it: render.pass."+name+")")
	}
	if name == "state" && len(spec.Values) == 0 {
		errs = append(errs, where+": control state needs a list of states")
	}
	if name == "hud" || len(def.values) == 0 {
		return errs
	}
	for _, v := range spec.Values {
		if !slices.Contains(def.values, v) {
			errs = append(errs, where+": control "+name+" has no value "+v)
		}
	}
	return errs
}
