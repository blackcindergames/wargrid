package rounds

import (
	"encoding/json"
	"fmt"
	"reflect"

	"github.com/invopop/jsonschema"
)

// Schema is the JSON Schema of round.yaml (kind "round") or of a step file (kind "step"), for editor help;
// the strict decoder stays the authority.
func Schema(kind string) ([]byte, error) {
	var t reflect.Type
	switch kind {
	case "round":
		t = reflect.TypeFor[Round]()
	case "step":
		t = reflect.TypeFor[Step]()
	default:
		return nil, fmt.Errorf("schema: unknown kind %q (round or step)", kind)
	}
	r := &jsonschema.Reflector{
		FieldNameTag:               "yaml",
		RequiredFromJSONSchemaTags: true,
		Anonymous:                  true,
		ExpandedStruct:             true,
		Mapper:                     customTypes,
	}
	root := r.ReflectFromType(t)
	// Marks refer to Mark, which no field names on its own.
	mark := r.ReflectFromType(reflect.TypeFor[Mark]())
	mark.Version = ""
	root.Definitions["Mark"] = mark
	if kind == "step" {
		// A null line is where the option's text goes.
		lines, _ := root.Definitions["Card"].Properties.Get("lines")
		lines.Items = &jsonschema.Schema{AnyOf: []*jsonschema.Schema{{Type: "string"}, {Type: "null"}}}
		kinds, _ := root.Properties.Get("kind")
		kinds.Enum = nil
		for _, k := range allKinds {
			kinds.Enum = append(kinds.Enum, k)
		}
	}
	out, err := json.MarshalIndent(root, "", "  ")
	return append(out, '\n'), err
}

// customTypes describes the types whose YAML is not the shape of their Go struct.
func customTypes(t reflect.Type) *jsonschema.Schema {
	mark := &jsonschema.Schema{Ref: "#/$defs/Mark"}
	switch t {
	case reflect.TypeFor[Marks]():
		return &jsonschema.Schema{OneOf: []*jsonschema.Schema{mark, {Type: "array", Items: mark}}}
	case reflect.TypeFor[Pair]():
		four := uint64(4)
		five := uint64(5)
		return &jsonschema.Schema{Type: "array", Items: &jsonschema.Schema{Type: "string"}, MinItems: &four, MaxItems: &five}
	case reflect.TypeFor[Params]():
		scalar := []*jsonschema.Schema{{Type: "string"}, {Type: "number"}, {Type: "boolean"}}
		return &jsonschema.Schema{Type: "object", AdditionalProperties: &jsonschema.Schema{AnyOf: scalar}}
	case reflect.TypeFor[ControlSpec]():
		return &jsonschema.Schema{OneOf: []*jsonschema.Schema{{Const: true}, {Type: "array", Items: &jsonschema.Schema{Type: "string"}}}}
	}
	return nil
}
