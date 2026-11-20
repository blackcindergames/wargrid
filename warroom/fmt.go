package main

import "regexp"

var markRE = regexp.MustCompile("`([^`]+)`")

// FmtPart is a stretch of text; Bold marks the words the author wrapped in backticks.
type FmtPart struct {
	Text string
	Bold bool
}

func fmtParts(s string) []FmtPart {
	var out []FmtPart
	last := 0
	for _, m := range markRE.FindAllStringSubmatchIndex(s, -1) {
		if m[0] > last {
			out = append(out, FmtPart{s[last:m[0]], false})
		}
		out = append(out, FmtPart{s[m[2]:m[3]], true})
		last = m[1]
	}
	if last < len(s) {
		out = append(out, FmtPart{s[last:], false})
	}
	return out
}
