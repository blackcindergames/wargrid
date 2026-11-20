package web

import (
	"net/url"
	"strconv"
	"strings"
	"wargrid/warroom/internal/rounds"
)

// Query is the view state a page address carries; the names are the prototype's hash names.
type Query struct {
	Ctl     map[string]string
	Show    string
	View    string
	Item    string
	Numbers bool
	Lab     bool
	Shot    bool
	Keys    bool
	Phone   bool
	Crop    string
}

func parseQuery(v url.Values) Query {
	q := Query{
		Ctl: map[string]string{}, Show: v.Get("show"), View: v.Get("view"), Item: v.Get("item"), Numbers: v.Get("numbers") != "0",
		Lab: v.Get("lab") == "1", Shot: v.Get("shot") == "1", Keys: v.Get("keys") == "1", Phone: v.Get("phone") == "1", Crop: v.Get("crop"),
	}
	extras := 0
	for k := range v {
		_, known := rounds.ControlDefs[k]
		extra := !known && strings.HasPrefix(k, "x-") && len(k) <= maxCtlValue
		if (!known && !extra) || !ctlValueOK(v.Get(k)) || (extra && extras >= maxExtraCtls) {
			continue
		}
		if extra {
			extras++
		}
		q.Ctl[k] = v.Get(k)
	}
	return q
}

// Control values are copied into every link on the page, so a long query would multiply the response.
const (
	maxCtlValue  = 64
	maxExtraCtls = 16
)

func ctlValueOK(s string) bool {
	if len(s) > maxCtlValue {
		return false
	}
	for _, c := range []byte(s) {
		ok := c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || strings.IndexByte(" ._,:+-", c) >= 0
		if !ok {
			return false
		}
	}
	return true
}

// Carry is the part of the query that stays page-wide when you move between steps.
func (q *Query) Carry() url.Values {
	out := url.Values{}
	for k, v := range q.Ctl {
		out.Set(k, v)
	}
	if !q.Numbers {
		out.Set("numbers", "0")
	}
	if q.Phone {
		out.Set("phone", "1")
	}
	return out
}

// WithCtl is the carried query with one control set; first is the value that needs no parameter.
func (q *Query) WithCtl(name, value, first string) url.Values {
	out := q.Carry()
	if value == first {
		out.Del(name)
	} else {
		out.Set(name, value)
	}
	return out
}

func withQuery(path string, v url.Values) string {
	if len(v) == 0 {
		return path
	}
	return path + "?" + v.Encode()
}

func roundURL(round *rounds.Round) string { return "/r/" + round.ID }

func stepURL(round *rounds.Round, n int, v url.Values) string {
	return withQuery(roundURL(round)+"/"+strconv.Itoa(n), v)
}

func summaryURL(round *rounds.Round, v url.Values) string {
	return withQuery(roundURL(round)+"/summary", v)
}

func pickURL(round *rounds.Round, step *rounds.Step, v url.Values) string {
	return withQuery(roundURL(round)+"/"+step.Key+"/pick", v)
}

func noteURL(round *rounds.Round, step *rounds.Step) string {
	return roundURL(round) + "/" + step.Key + "/note"
}
