package rounds

import (
	"strings"
	"testing"
)

const tuneStepYAML = `kind: tune
question: Tune it?
neutral: None of these
target: {page: static/demo/scene.html, hash: shot=1}
params:
- {id: outline, label: Outline, min: 0, max: 4, step: 0.5, value: 1}
- {id: unit, label: Unit size, min: 0.5, max: 2, step: 0.1, value: 1}
- {id: you, label: Owner colour, color: '#376eac'}
- {id: ground, label: Ground, values: [sand, dark], value: sand}
`

func TestTuneLoadErrors(t *testing.T) {
	param := func(p string) string {
		return "kind: tune\ntarget: {page: x.html}\nparams:\n- " + p + "\n"
	}
	cases := []struct{ name, yaml, want string }{
		{"no target", "kind: tune\nparams:\n- {id: a, color: '#112233'}\n", "tune needs target.page"},
		{"no params", "kind: tune\ntarget: {page: x.html}\n", "tune needs 1 to 12 params"},
		{"too many", "kind: tune\ntarget: {page: x.html}\nparams:\n" + strings.Repeat("- {id: a, color: '#112233'}\n", 13), "tune needs 1 to 12 params, has 13"},
		{"bad id", param("{id: Bad_Id, color: '#112233'}"), `bad param id "Bad_Id"`},
		{"unknown field", param("{id: a, color: '#112233', colour: x}"), "unknown field"},
		{"two kinds", param("{id: a, color: '#112233', values: [x], value: x}"), "exactly one of"},
		{"no kind", param("{id: a}"), "exactly one of"},
		{"zero step", param("{id: a, min: 0, max: 1, step: 0, value: 0}"), "step > 0"},
		{"min above max", param("{id: a, min: 2, max: 1, step: 1, value: 1}"), "min < max"},
		{"value out of range", param("{id: a, min: 0, max: 1, step: 0.5, value: 2}"), "in range and on the step grid"},
		{"value off the grid", param("{id: a, min: 0, max: 1, step: 0.5, value: 0.3}"), "in range and on the step grid"},
		{"value not a number", param("{id: a, min: 0, max: 1, step: 0.5, value: x}"), "numeric value"},
		{"bad colour", param("{id: a, color: red}"), "#rrggbb"},
		{"colour with value", param("{id: a, color: '#112233', value: 1}"), "#rrggbb"},
		{"choice value missing", param("{id: a, values: [x, y], value: z}"), "one of values"},
		{"duplicate choices", param("{id: a, values: [x, x], value: x}"), "one of values"},
		{"duplicate ids", "kind: tune\ntarget: {page: x.html}\nparams:\n- {id: a, color: '#112233'}\n- {id: a, color: '#112233'}\n", "param a appears twice"},
	}
	for _, tc := range cases {
		c := oneRound(t, "steps: [s]\n", map[string]string{"s": tc.yaml})
		if !hasError(c, tc.want) {
			t.Errorf("%s: want error containing %q, got %v", tc.name, tc.want, c.Errors)
		}
	}
	if c := oneRound(t, "steps: [s]\n", map[string]string{"s": tuneStepYAML}); len(c.Errors) > 0 {
		t.Errorf("a valid tune step: %v", c.Errors)
	}
}
