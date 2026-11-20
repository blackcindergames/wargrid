package web

import (
	"cmp"
	"hash/fnv"
	"os"
	"slices"
	"strconv"
	"strings"
	"wargrid/warroom/internal/rounds"
	"wargrid/warroom/internal/stage"

	"github.com/a-h/templ"
)

type MarkView struct {
	Style        templ.SafeCSS
	Label        string
	Right, Below bool
}

type HudLayer struct {
	ID    string
	Src   string
	Style templ.SafeCSS
}

// PicView is one picture of the stage: a live render in an iframe, a still, a clip or a notice.
type PicView struct {
	// Kind is frame, img, video, missing or none.
	Kind  string
	Label string
	// Large: a stage picture, which has a large view; a thumbnail has none.
	Large bool
	Live  bool
	Marks []MarkView

	URL   string
	Local bool

	Src        string
	FrameID    string
	Title      string
	Style      templ.SafeCSS
	ScStyle    templ.SafeCSS
	FrameStyle templ.SafeCSS
	CW         string
	Hud        *HudLayer
	Whole      *PicView
}

// picSrc is what the Option, Item and Pic types share.
type picSrc struct {
	Img    string
	Local  bool
	Video  string
	Render *rounds.Render
	Mark   rounds.Marks
}

func optionSrc(o *rounds.Option) picSrc { return picSrc{o.Img, o.Local, o.Video, o.Render, o.Mark} }
func itemSrc(i *rounds.Item) picSrc     { return picSrc{i.Img, i.Local, "", i.Render, i.Mark} }
func picOf(p *rounds.Pic) picSrc        { return picSrc{p.Img, p.Local, "", p.Render, nil} }

type picBuilder struct {
	st   *stage.Stage
	root *os.Root
}

func num(f float64) string {
	if f == 0 {
		f = 0
	}
	return strconv.FormatFloat(f, 'f', -1, 64)
}

func px(f float64) string { return num(f) + "px" }

func (b picBuilder) served(path string) bool {
	if b.root == nil {
		return false
	}
	tree, _, _ := strings.Cut(path, "/")
	if !slices.Contains(siteTrees, tree) {
		return false
	}
	info, err := b.root.Stat(path)
	return err == nil && !info.IsDir()
}

func (b picBuilder) pic(src picSrc, crop0 *rounds.Crop, label string, large bool) PicView {
	switch {
	case src.Video != "":
		return b.file(src.Video, src.Local, "video", label)
	case src.Img != "":
		v := b.file(src.Img, src.Local, "img", label)
		v.Large = large
		if v.Kind == "img" && large {
			v.Marks = b.imgMarks(src)
		}
		return v
	case src.Render != nil:
		return b.frame(src, crop0, label, large)
	}
	return PicView{Kind: "none"}
}

func (b picBuilder) file(path string, local bool, kind, label string) PicView {
	v := PicView{Kind: kind, Label: label, URL: stage.RepoURL(path), Local: local}
	if !b.served(path) {
		v.Kind = "missing"
		v.URL = path
	}
	return v
}

func (b picBuilder) markOn(src picSrc) rounds.Marks {
	if b.st.Value("marker") != "on" {
		return nil
	}
	if len(src.Mark) > 0 {
		return src.Mark
	}
	return b.st.Step.Mark
}

func (b picBuilder) imgMarks(src picSrc) []MarkView {
	var out []MarkView
	pc := func(v, t float64) string { return num(v/t*100) + "%" }
	for _, m := range b.markOn(src) {
		style := "left:" + pc(float64(m.X), 1280) + ";top:" + pc(float64(m.Y), 720) + ";width:" + pc(float64(m.W), 1280) + ";height:" + pc(float64(m.H), 720)
		out = append(out, MarkView{templ.SafeCSS(style), m.Label, float64(m.X)+float64(m.W)/2 > 640, m.Below})
	}
	return out
}

func (b picBuilder) frame(src picSrc, crop0 *rounds.Crop, label string, large bool) PicView {
	r := src.Render
	base := b.st.Base(r)
	baseW, baseH := cmp.Or(base.W, 1280), cmp.Or(base.H, 720)
	z := b.st.Geometry(r)
	crop := r.Crop
	if crop == nil {
		crop = crop0
	}
	c := stage.CropFor(crop, baseW, baseH, z)
	frameSrc := b.st.FrameSrc(r)
	frameStyle := templ.SafeCSS("width:" + px(z.W) + ";height:" + px(z.H) + ";left:" + px(-c.X) + ";top:" + px(-c.Y))
	v := PicView{
		Kind: "frame", Label: label, Large: large, Live: large && b.st.Step.Interactive,
		Src: frameSrc, FrameID: frameID(frameSrc, large), Title: b.st.StateFor(r), CW: num(c.W),
		Style:      templ.SafeCSS("--ar:" + num(c.W) + "/" + num(c.H) + ";--cw:" + num(c.W)),
		ScStyle:    templ.SafeCSS("width:" + px(c.W) + ";height:" + px(c.H)),
		FrameStyle: frameStyle,
	}
	if hud := b.st.HudLayerSrc(z); hud != "" {
		v.Hud = &HudLayer{frameID(frameSrc+" "+hud, large), hud, frameStyle}
	}
	if large {
		v.Marks = b.frameMarks(src, c, z, baseW, baseH)
		if crop != nil {
			v.Whole = b.whole(src, label)
		}
	}
	return v
}

func (b picBuilder) frameMarks(src picSrc, c stage.Rect, z stage.Geometry, baseW, baseH int) []MarkView {
	var out []MarkView
	for _, m := range b.markOn(src) {
		r := stage.CropFor(&rounds.Crop{X: m.X, Y: m.Y, W: m.W, H: m.H}, baseW, baseH, z)
		style := "left:" + px(r.X-c.X) + ";top:" + px(r.Y-c.Y) + ";width:" + px(r.W) + ";height:" + px(r.H)
		out = append(out, MarkView{templ.SafeCSS(style), m.Label, float64(m.X)+float64(m.W)/2 > float64(baseW)/2, m.Below})
	}
	return out
}

// whole is the picture without its crop, for the large view; it sits in a template so it loads nothing until opened.
func (b picBuilder) whole(src picSrc, label string) *PicView {
	r := *src.Render
	r.Crop = nil
	src.Render = &r
	v := b.frame(src, nil, label, true)
	v.Whole = nil
	return &v
}

// frameID changes with the address, so a morph replaces a frame whose hash changed (a hash change alone reloads nothing).
func frameID(src string, large bool) string {
	h := fnv.New32a()
	_, _ = h.Write([]byte(src))
	if large {
		_, _ = h.Write([]byte{1})
	}
	return "fr" + strconv.FormatUint(uint64(h.Sum32()), 36)
}
