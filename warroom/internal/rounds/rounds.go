package rounds

import (
	"cmp"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strings"
	"wargrid/warroom/internal/store"

	"github.com/goccy/go-yaml"
)

// The data contract is tools/decision_page/README.md, "Rounds: the data contract".

const KindMissing = "missing"

var (
	idRE  = regexp.MustCompile(`^[a-z0-9][a-z0-9-]*$`)
	hexRE = regexp.MustCompile(`^#[0-9a-fA-F]{6}$`)

	choiceKinds = []string{"pictures", "text", "audio", "lab"}
	allKinds    = append([]string{"gallery", "verdict", "wording", "tune"}, choiceKinds...)
	letters     = []string{"A", "B", "C", "D", "E", "F", "G", "H"}
)

type IndexEntry struct {
	ID    string `yaml:"id"`
	Title string `yaml:"title"`
	Demo  bool   `yaml:"demo"`
}

type Crop struct {
	X int `yaml:"x"`
	Y int `yaml:"y"`
	W int `yaml:"w"`
	H int `yaml:"h"`
}

type Mark struct {
	X     int    `yaml:"x"`
	Y     int    `yaml:"y"`
	W     int    `yaml:"w"`
	H     int    `yaml:"h"`
	Label string `yaml:"label"`
	Below bool   `yaml:"below"`
}

// Marks is one mark or a list of them.
type Marks []Mark

func (m *Marks) UnmarshalYAML(decode func(any) error) error {
	var many []Mark
	if decode(&many) == nil {
		*m = many
		return nil
	}
	var one Mark
	if err := decode(&one); err != nil {
		return err
	}
	*m = Marks{one}
	return nil
}

// Pair is a colour pair for the numbers panel; Kind "vs" means the two only need to differ.
type Pair struct {
	AName, AHex, BName, BHex, Kind string
}

func (p *Pair) UnmarshalYAML(decode func(any) error) error {
	var f []string
	if err := decode(&f); err != nil {
		return err
	}
	if len(f) != 4 && len(f) != 5 {
		return fmt.Errorf("a pair is [name, #hex, name, #hex] or with a kind, got %d items", len(f))
	}
	if !hexRE.MatchString(f[1]) || !hexRE.MatchString(f[3]) {
		return fmt.Errorf("pair %q: colours must be #rrggbb", f[0])
	}
	*p = Pair{AName: f[0], AHex: f[1], BName: f[2], BHex: f[3]}
	if len(f) == 5 {
		if f[4] != "vs" {
			return fmt.Errorf("pair %q: kind must be vs", f[0])
		}
		p.Kind = f[4]
	}
	return nil
}

// Render is a live-render recipe; the round, the step and the option each give part of it.
type Render struct {
	Page   string            `yaml:"page"`
	W      int               `yaml:"w"`
	H      int               `yaml:"h"`
	Hash   string            `yaml:"hash"`
	Pass   map[string]string `yaml:"pass"`
	State  string            `yaml:"state"`
	Crop   *Crop             `yaml:"crop"`
	Params Params            `yaml:"params"`
}

// Params keep their YAML order, which is the order the render page reads its hash in.
type Params []KV

// KV is a render-page hash parameter.
type KV struct{ K, V string }

func (p *Params) UnmarshalYAML(unmarshal func(any) error) error {
	var m yaml.MapSlice
	if err := unmarshal(&m); err != nil {
		return err
	}
	for _, it := range m {
		switch it.Value.(type) {
		case string, bool, int, int64, uint64, float64:
		default:
			return fmt.Errorf("params: %v is not a plain value", it.Key)
		}
		*p = append(*p, KV{fmt.Sprint(it.Key), fmt.Sprint(it.Value)})
	}
	return nil
}

func (r *Render) passMap() map[string]string {
	if r == nil {
		return nil
	}
	return r.Pass
}

// Pic is a labelled picture: a still (Img; Local when the file is never committed) or a live render.
type Pic struct {
	Label  string  `yaml:"label"`
	Img    string  `yaml:"img"`
	Local  bool    `yaml:"local"`
	Render *Render `yaml:"render"`
}

type Fold struct {
	Label string `yaml:"label"`
	Text  string `yaml:"text"`
	Pics  []Pic  `yaml:"pics"`
}

type Option struct {
	Name    string  `yaml:"name"`
	Notes   string  `yaml:"notes"`
	Sees    string  `yaml:"sees"`
	Changes string  `yaml:"changes"`
	Reveal  string  `yaml:"reveal"`
	Extra   []Pic   `yaml:"extra"`
	Folds   []Fold  `yaml:"folds"`
	Mark    Marks   `yaml:"mark"`
	Img     string  `yaml:"img"`
	Local   bool    `yaml:"local"`
	Render  *Render `yaml:"render"`
	Video   string  `yaml:"video"`
	Text    string  `yaml:"text"`
	Audio   string  `yaml:"audio"`
	Level   string  `yaml:"level"`
}

// Card frames text options; a nil line is where the option's text goes.
type Card struct {
	Title string    `yaml:"title"`
	Lines []*string `yaml:"lines"`
	Foot  string    `yaml:"foot"`
}

type Item struct {
	ID      string  `yaml:"id"`
	Label   string  `yaml:"label"`
	Caption string  `yaml:"caption"`
	Img     string  `yaml:"img"`
	Local   bool    `yaml:"local"`
	Render  *Render `yaml:"render"`
	Mark    Marks   `yaml:"mark"`
}

type Verdict struct {
	Key     string `yaml:"key"`
	Pass    string `yaml:"pass"`
	Changes string `yaml:"changes"`
}

type Labels struct {
	Pass    string `yaml:"pass"`
	Changes string `yaml:"changes"`
}

type Field struct {
	ID    string `yaml:"id"`
	Label string `yaml:"label"`
	Text  string `yaml:"text"`
}

// Step is one question. Key comes from the file name.
type Step struct {
	Key         string            `yaml:"-"`
	Kind        string            `yaml:"kind"`
	Question    string            `yaml:"question"`
	Why         string            `yaml:"why"`
	Look        string            `yaml:"look"`
	Rec         string            `yaml:"rec"`
	RecWhy      string            `yaml:"recWhy"`
	Options     map[string]Option `yaml:"options"`
	Uses        []string          `yaml:"uses"`
	Neutral     string            `yaml:"neutral"`
	Blind       bool              `yaml:"blind"`
	View        string            `yaml:"view"`
	Crop        *Crop             `yaml:"crop"`
	PhoneCrop   *Crop             `yaml:"phoneCrop"`
	Ref         *Pic              `yaml:"ref"`
	NotesLabel  string            `yaml:"notesLabel"`
	Controls    *Controls         `yaml:"controls"`
	Render      *Render           `yaml:"render"`
	Mark        Marks             `yaml:"mark"`
	Pairs       []Pair            `yaml:"pairs"`
	Interactive bool              `yaml:"interactive"`
	Checklist   []string          `yaml:"checklist"`
	Folds       []Fold            `yaml:"folds"`
	Card        *Card             `yaml:"card"`
	URL         string            `yaml:"url"`
	W           int               `yaml:"w"`
	H           int               `yaml:"h"`
	LabHint     string            `yaml:"labHint"`
	Items       []Item            `yaml:"items"`
	Verdict     *Verdict          `yaml:"verdict"`
	Labels      *Labels           `yaml:"labels"`
	Fields      []Field           `yaml:"fields"`
	Target      *Render           `yaml:"target"`
	Params      []TuneParam       `yaml:"params"`
}

// Round is a folder of steps. ID is the folder name; Prefix defaults to it.
type Round struct {
	ID       string    `yaml:"-"`
	Prefix   string    `yaml:"prefix"`
	Title    string    `yaml:"title"`
	Intro    string    `yaml:"intro"`
	Steps    []string  `yaml:"steps"`
	Earlier  []string  `yaml:"earlier"`
	Render   *Render   `yaml:"render"`
	Controls *Controls `yaml:"controls"`
	// Loaded holds the steps in order; a step whose file did not load has Kind "missing".
	Loaded []Step `yaml:"-"`
}

// Catalog is everything the index names, loaded from disk; Errors feed the page's red banner.
type Catalog struct {
	Index  []IndexEntry
	Rounds map[string]*Round
	Errors []string
}

func (s *Step) IsChoice() bool { return slices.Contains(choiceKinds, s.Kind) }

func (s *Step) OptionLetters() []string {
	var out []string
	for _, l := range letters {
		if _, ok := s.Options[l]; ok {
			out = append(out, l)
		}
	}
	return out
}

// IsConfirm: a choice step with one option answers Yes, as drawn, or Change.
func (s *Step) IsConfirm() bool { return s.IsChoice() && len(s.Options) == 1 }

func (s *Step) VerdictKey() string {
	if s.Verdict == nil || s.Verdict.Key == "" {
		return "verdict"
	}
	return s.Verdict.Key
}

// AnswerKey is the picks key (without prefix) that holds the step's answer; "" for steps with none.
func (s *Step) AnswerKey() string {
	switch {
	case s.IsChoice(), s.Kind == "verdict", s.Kind == "tune":
		return s.Key
	case s.Kind == "gallery" && s.Verdict != nil:
		return s.VerdictKey()
	}
	return ""
}

// ChipKey is the key of the step's chip: its answer key, or the step key for a step without one.
func (s *Step) ChipKey() string { return cmp.Or(s.AnswerKey(), s.Key) }

// AcceptsPick says whether pick is an answer this step can record.
func (s *Step) AcceptsPick(pick string) bool {
	switch {
	case s.IsChoice():
		if _, ok := s.Options[pick]; ok {
			return true
		}
		return (pick == "neither" && s.Neutral != "") || (s.IsConfirm() && (pick == "yes" || pick == "change"))
	case s.Kind == "verdict", s.Kind == "gallery" && s.Verdict != nil:
		return pick == "pass" || pick == "changes"
	case s.Kind == "tune":
		return pick == "tuned" || (pick == "neither" && s.Neutral != "")
	}
	return false
}

// Open lists the indexes of the steps that have no pick yet.
func (r *Round) Open(entries map[string]store.Entry) []int {
	var open []int
	for i := range r.Loaded {
		s := &r.Loaded[i]
		if k := s.AnswerKey(); k != "" && entries[r.Prefix+":"+k].Pick == nil {
			open = append(open, i)
		}
	}
	return open
}

func (r *Round) Step(key string) *Step {
	for i := range r.Loaded {
		if r.Loaded[i].Key == key && r.Loaded[i].Kind != KindMissing {
			return &r.Loaded[i]
		}
	}
	return nil
}

func (c *Catalog) Round(id string) *Round { return c.Rounds[id] }

// LoadCatalog reads index.yaml and every round it lists, strictly; problems are collected, not fatal.
func LoadCatalog(dir string) *Catalog {
	c := &Catalog{Rounds: map[string]*Round{}}
	if err := decodeFile(filepath.Join(dir, "index.yaml"), &c.Index); err != nil {
		c.fail("index.yaml: %v", err)
		return c
	}
	for _, e := range c.Index {
		if !idRE.MatchString(e.ID) {
			c.fail("index.yaml: bad round id %q", e.ID)
			continue
		}
		if r := loadRound(c, dir, e.ID); r != nil {
			c.Rounds[e.ID] = r
		}
	}
	for _, r := range c.Rounds {
		c.validateRound(r)
	}
	c.checkPrefixes()
	slices.Sort(c.Errors)
	return c
}

// checkPrefixes refuses a shared prefix: picks keys are per prefix but write tokens per round, so one round's token could overwrite the other's picks.
func (c *Catalog) checkPrefixes() {
	owner := map[string]string{}
	for _, e := range c.Index {
		r := c.Rounds[e.ID]
		if r == nil {
			continue
		}
		if first, taken := owner[r.Prefix]; taken {
			c.fail("rounds %s and %s share the prefix %s", first, r.ID, r.Prefix)
			continue
		}
		owner[r.Prefix] = r.ID
	}
}

func (c *Catalog) fail(format string, args ...any) {
	c.Errors = append(c.Errors, fmt.Sprintf(format, args...))
}

func decodeFile(path string, into any) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	return yaml.UnmarshalWithOptions(data, into, yaml.Strict())
}

func loadRound(c *Catalog, dir, id string) *Round {
	r := &Round{}
	if err := decodeFile(filepath.Join(dir, id, "round.yaml"), r); err != nil {
		c.fail("%s/round.yaml: %v", id, err)
		return nil
	}
	r.ID = id
	if r.Prefix == "" {
		r.Prefix = id
	}
	for _, key := range r.Steps {
		r.Loaded = append(r.Loaded, loadStep(c, dir, r, key))
	}
	return r
}

func loadStep(c *Catalog, dir string, r *Round, key string) Step {
	missing := Step{Key: key, Kind: KindMissing}
	if !idRE.MatchString(key) {
		c.fail("%s: bad step key %q", r.ID, key)
		return missing
	}
	var s Step
	err := decodeFile(filepath.Join(dir, r.ID, key+".yaml"), &s)
	switch {
	case errors.Is(err, os.ErrNotExist):
		c.fail("%s/%s: [step missing: %s] rounds/%s/%s.yaml did not load", r.ID, key, key, r.ID, key)
		return missing
	case err != nil:
		c.fail("%s/%s.yaml: %v", r.ID, key, err)
		return missing
	}
	s.Key = key
	return s
}

func (c *Catalog) validateRound(r *Round) {
	if !idRE.MatchString(r.Prefix) {
		c.fail("%s: bad prefix %q", r.ID, r.Prefix)
	}
	if d := firstDuplicate(r.Steps); d != "" {
		c.fail("%s: step %s is listed twice", r.ID, d)
	}
	for _, e := range r.Earlier {
		if c.Rounds[e] == nil {
			c.fail("%s: earlier round %s is not in the index", r.ID, e)
		}
	}
	for i := range r.Loaded {
		c.validateStep(r, &r.Loaded[i])
	}
}

func (c *Catalog) validateStep(r *Round, s *Step) {
	if s.Kind == KindMissing {
		return
	}
	where := r.ID + "/" + s.Key
	if !slices.Contains(allKinds, s.Kind) {
		c.fail("%s: unknown kind %q", where, s.Kind)
	}
	c.Errors = append(c.Errors, validateControls(where, r, s)...)
	c.Errors = append(c.Errors, validateChoice(where, s)...)
	c.Errors = append(c.Errors, validateTune(where, s)...)
	for _, u := range s.Uses {
		if !c.useExists(r, u) {
			c.fail("%s: uses %s is not a step", where, u)
		}
	}
	c.Errors = append(c.Errors, validateGallery(where, r, s)...)
	if s.Kind == "wording" && len(s.Fields) == 0 {
		c.fail("%s: no fields", where)
	}
	for _, id := range ids(s.Fields, func(f Field) string { return f.ID }) {
		if !idRE.MatchString(id) {
			c.fail("%s: bad field id %q", where, id)
		}
	}
}

func validateChoice(where string, s *Step) []string {
	if !s.IsChoice() {
		return nil
	}
	var errs []string
	if len(s.Options) == 0 {
		return []string{where + ": no options"}
	}
	for l := range s.Options {
		if !slices.Contains(letters, l) {
			errs = append(errs, where+": option "+l+" is not one of A to H")
		}
	}
	if _, ok := s.Options[s.Rec]; s.Rec != "" && !ok {
		errs = append(errs, where+": rec "+s.Rec+" is not an option")
	}
	return errs
}

func validateGallery(where string, r *Round, s *Step) []string {
	if s.Kind != "gallery" {
		return nil
	}
	var errs []string
	if len(s.Items) == 0 {
		errs = append(errs, where+": no items")
	}
	itemIDs := ids(s.Items, func(i Item) string { return i.ID })
	for _, id := range itemIDs {
		if !idRE.MatchString(id) {
			errs = append(errs, fmt.Sprintf("%s: bad item id %q", where, id))
		}
	}
	if d := firstDuplicate(itemIDs); d != "" {
		errs = append(errs, where+": item "+d+" appears twice")
	}
	if s.Verdict != nil {
		k := s.VerdictKey()
		if !idRE.MatchString(k) {
			errs = append(errs, fmt.Sprintf("%s: bad verdict key %q", where, k))
		}
		if slices.Contains(r.Steps, k) {
			errs = append(errs, where+": verdict key "+k+" is also a step key")
		}
	}
	return errs
}

// useExists resolves "<step>" in the round or "<round>/<step>" in the round or an earlier one.
func (c *Catalog) useExists(from *Round, ref string) bool {
	id, key, qualified := strings.Cut(ref, "/")
	if !qualified {
		id, key = from.ID, ref
	}
	target := c.Rounds[id]
	if target == nil || (id != from.ID && !slices.Contains(from.Earlier, id)) {
		return false
	}
	return target.Step(key) != nil
}

func ids[T any](list []T, id func(T) string) []string {
	out := make([]string, len(list))
	for i, v := range list {
		out[i] = id(v)
	}
	return out
}

func firstDuplicate(list []string) string {
	seen := map[string]bool{}
	for _, v := range list {
		if seen[v] {
			return v
		}
		seen[v] = true
	}
	return ""
}
