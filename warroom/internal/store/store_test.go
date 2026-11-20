package store

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
)

func newTestStore(t *testing.T) (*Store, string) {
	t.Helper()
	path := filepath.Join(t.TempDir(), "data", "picks.json")
	return NewStore(path), path
}

func setEntry(pick string, note string) func(Entry) Entry {
	return func(Entry) Entry {
		e := Entry{Note: note}
		if pick != "" {
			e.Pick = &pick
		}
		return e
	}
}

func readFile(t *testing.T, path string) map[string]Entry {
	t.Helper()
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var got map[string]Entry
	if err := json.Unmarshal(raw, &got); err != nil {
		t.Fatal(err)
	}
	return got
}

func TestStoreWritesAndReadsBack(t *testing.T) {
	s, path := newTestStore(t)
	if err := s.Update("demo:pictures", setEntry("B", "fine")); err != nil {
		t.Fatal(err)
	}
	if err := s.Update("gate2:look:slab", setEntry("", "x")); err != nil {
		t.Fatal(err)
	}
	got := readFile(t, path)
	if p := got["demo:pictures"].Pick; p == nil || *p != "B" || got["demo:pictures"].Note != "fine" {
		t.Fatalf("demo:pictures = %+v", got["demo:pictures"])
	}
	if got["gate2:look:slab"].Pick != nil {
		t.Fatalf("a note alone must store pick null: %+v", got["gate2:look:slab"])
	}
	entries, err := s.Entries()
	if err != nil || len(entries) != 2 {
		t.Fatalf("Entries = %v, %v", entries, err)
	}
}

func TestStoreMissingFileReadsEmpty(t *testing.T) {
	s, _ := newTestStore(t)
	entries, err := s.Entries()
	if err != nil || len(entries) != 0 {
		t.Fatalf("Entries = %v, %v", entries, err)
	}
}

func TestStoreUpdateSeesTheOldEntry(t *testing.T) {
	s, _ := newTestStore(t)
	if err := s.Update("demo:a", setEntry("A", "first")); err != nil {
		t.Fatal(err)
	}
	keepPick := func(old Entry) Entry { old.Note = "second"; return old }
	if err := s.Update("demo:a", keepPick); err != nil {
		t.Fatal(err)
	}
	got, _ := s.Entries()
	if p := got["demo:a"].Pick; p == nil || *p != "A" || got["demo:a"].Note != "second" {
		t.Fatalf("entry = %+v", got["demo:a"])
	}
}

func TestStoreRejectsBadKeys(t *testing.T) {
	s, path := newTestStore(t)
	bad := []string{"", "other", "demo:", ":x", "demo:../x", "demo:x\n", "Demo:x", "gate_2:x", "demo:" + strings.Repeat("x", maxKeyLen)}
	for _, key := range bad {
		if err := s.Update(key, setEntry("A", "")); !errors.Is(err, ErrBadKey) {
			t.Errorf("Update(%q) = %v, want ErrBadKey", key, err)
		}
	}
	if _, err := os.Stat(path); !os.IsNotExist(err) {
		t.Fatalf("a bad key wrote the file: %v", err)
	}
}

func TestStoreCapsNewKeys(t *testing.T) {
	s, path := newTestStore(t)
	s.maxKeys = 2
	for _, key := range []string{"demo:a", "demo:b"} {
		if err := s.Update(key, setEntry("A", "")); err != nil {
			t.Fatal(err)
		}
	}
	if err := s.Update("demo:c", setEntry("A", "")); !errors.Is(err, ErrFull) {
		t.Fatalf("third key = %v, want ErrFull", err)
	}
	if err := s.Update("demo:a", setEntry("B", "")); err != nil {
		t.Fatalf("existing key past the cap = %v", err)
	}
	got := readFile(t, path)
	if len(got) != 2 || got["demo:c"].Note != "" {
		t.Fatalf("keys = %v", got)
	}
}

func TestStoreBadFileIsAnErrorAndKept(t *testing.T) {
	for _, text := range []string{"{not json", `["demo:a"]`, `{"demo:a": null}`, `{"demo:a": "x"}`, `{"demo:a": []}`} {
		s, path := newTestStore(t)
		if err := os.MkdirAll(filepath.Dir(path), 0o750); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte(text), 0o600); err != nil {
			t.Fatal(err)
		}
		if _, err := s.Entries(); err == nil {
			t.Errorf("Entries on %q succeeded", text)
		}
		if err := s.Update("demo:b", setEntry("A", "")); err == nil {
			t.Errorf("Update on %q succeeded", text)
		}
		if got, _ := os.ReadFile(path); string(got) != text {
			t.Errorf("file %q was changed to %q", text, got)
		}
	}
}

func TestStoreKeepsUntouchedEntriesVerbatim(t *testing.T) {
	s, path := newTestStore(t)
	if err := os.MkdirAll(filepath.Dir(path), 0o750); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(`{"old:k": {"pick": "A", "note": "n", "extra": 7}}`), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := s.Update("demo:a", setEntry("B", "")); err != nil {
		t.Fatal(err)
	}
	raw, _ := os.ReadFile(path)
	if !strings.Contains(string(raw), `"extra": 7`) {
		t.Fatalf("an untouched entry lost a field: %s", raw)
	}
}

func TestStoreFailedWriteKeepsTheFile(t *testing.T) {
	s, path := newTestStore(t)
	if err := s.Update("demo:a", setEntry("A", "")); err != nil {
		t.Fatal(err)
	}
	s.write = func(string, []byte) error { return errors.New("disk full") }
	if err := s.Update("demo:b", setEntry("B", "")); err == nil {
		t.Fatal("a failed write was reported as success")
	}
	got := readFile(t, path)
	if len(got) != 1 || got["demo:a"].Pick == nil {
		t.Fatalf("file = %v", got)
	}
}

func TestWriteAtomicLeavesNoTempFile(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "picks.json")
	if err := writeAtomic(path, []byte(`{"a":{}}`)); err != nil {
		t.Fatal(err)
	}
	// A directory in the way makes the final rename fail after the temp file was written.
	blocked := filepath.Join(dir, "blocked")
	if err := os.MkdirAll(filepath.Join(blocked, "inner"), 0o750); err != nil {
		t.Fatal(err)
	}
	if err := writeAtomic(blocked, []byte("x")); err == nil {
		t.Fatal("rename onto a directory succeeded")
	}
	names := dirNames(t, dir)
	if len(names) != 2 || names[0] != "blocked" || names[1] != "picks.json" {
		t.Fatalf("directory = %v", names)
	}
}

func dirNames(t *testing.T, dir string) []string {
	t.Helper()
	items, err := os.ReadDir(dir)
	if err != nil {
		t.Fatal(err)
	}
	names := make([]string, 0, len(items))
	for _, it := range items {
		names = append(names, it.Name())
	}
	return names
}

func TestStoreConcurrentWritersAllLand(t *testing.T) {
	s, path := newTestStore(t)
	var wg sync.WaitGroup
	for i := range 20 {
		wg.Go(func() {
			if err := s.Update(fmt.Sprintf("demo:k%d", i), setEntry("A", "")); err != nil {
				t.Error(err)
			}
		})
	}
	wg.Wait()
	if got := readFile(t, path); len(got) != 20 {
		t.Fatalf("%d keys landed, want 20", len(got))
	}
	if names := dirNames(t, filepath.Dir(path)); len(names) != 1 {
		t.Fatalf("directory = %v", names)
	}
}
