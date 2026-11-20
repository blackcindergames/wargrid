package rounds

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestSchemaListsTheStepKindsAndTheStrictShape(t *testing.T) {
	out, err := Schema("step")
	if err != nil {
		t.Fatal(err)
	}
	var s struct {
		Properties           map[string]struct{ Enum []string }
		AdditionalProperties bool
		Defs                 map[string]json.RawMessage `json:"$defs"`
	}
	if err := json.Unmarshal(out, &s); err != nil {
		t.Fatal(err)
	}
	if got := strings.Join(s.Properties["kind"].Enum, ","); got != strings.Join(allKinds, ",") {
		t.Errorf("kind enum = %s", got)
	}
	if s.AdditionalProperties {
		t.Error("the schema allows fields the strict decoder refuses")
	}
	for _, def := range []string{"Mark", "Render", "Controls", "TuneParam"} {
		if s.Defs[def] == nil {
			t.Errorf("no definition for %s", def)
		}
	}
	if _, ok := s.Properties["Key"]; ok {
		t.Error("Key comes from the file name, not the YAML")
	}
}

func TestSchemaRejectsAnUnknownKind(t *testing.T) {
	if _, err := Schema("index"); err == nil {
		t.Error("an unknown kind produced a schema")
	}
}

func TestEveryShippedYAMLPointsAtItsSchema(t *testing.T) {
	files, err := filepath.Glob("../../rounds/*/*.yaml")
	if err != nil || len(files) == 0 {
		t.Fatalf("no round files: %v", err)
	}
	for _, f := range files {
		data, err := os.ReadFile(f)
		if err != nil {
			t.Fatal(err)
		}
		want := "# yaml-language-server: $schema=../step.schema.json"
		if filepath.Base(f) == "round.yaml" {
			want = "# yaml-language-server: $schema=../round.schema.json"
		}
		if first, _, _ := strings.Cut(string(data), "\n"); first != want {
			t.Errorf("%s starts with %q, want %q", f, first, want)
		}
	}
}
