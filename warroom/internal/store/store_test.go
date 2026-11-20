package store

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"sync"
	"testing"
	"time"
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

func TestCloseWaitsForAWriteInProgress(t *testing.T) {
	s, _ := newTestStore(t)
	writing, release := make(chan struct{}), make(chan struct{})
	s.write = func(path string, data []byte) error {
		close(writing)
		<-release
		return writeAtomic(path, data)
	}
	go func() { _ = s.Update("demo:a", setEntry("A", "")) }()
	<-writing
	closed := make(chan struct{})
	go func() { s.Close(); close(closed) }()
	select {
	case <-closed:
		t.Fatal("Close returned while a write was still running")
	case <-time.After(100 * time.Millisecond):
	}
	close(release)
	select {
	case <-closed:
	case <-time.After(3 * time.Second):
		t.Fatal("Close did not return after the write finished")
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
	if names := dirNames(t, filepath.Dir(path)); len(names) != 2 {
		t.Fatalf("directory = %v, want the picks and the history only", names)
	}
}

func historyLines(t *testing.T, s *Store) []string {
	t.Helper()
	data, err := s.History()
	if err != nil {
		t.Fatal(err)
	}
	return strings.Fields(string(data))
}

func TestHistoryAppendsOneLinePerChange(t *testing.T) {
	s, path := newTestStore(t)
	s.now = func() time.Time { return time.Date(2026, 11, 20, 4, 5, 6, 0, time.UTC) }
	for _, pick := range []string{"A", "A", "B"} {
		if err := s.Update("demo:k", setEntry(pick, "n")); err != nil {
			t.Fatal(err)
		}
	}
	if err := s.Update("demo:tune", func(Entry) Entry {
		p := "tuned"
		return Entry{Pick: &p, Value: map[string]any{"outline": 1.5}}
	}); err != nil {
		t.Fatal(err)
	}
	lines := historyLines(t, s)
	want := []string{
		`{"t":"2026-11-20T04:05:06Z","key":"demo:k","pick":"A","note":"n"}`,
		`{"t":"2026-11-20T04:05:06Z","key":"demo:k","pick":"B","note":"n"}`,
		`{"t":"2026-11-20T04:05:06Z","key":"demo:tune","pick":"tuned","note":"","value":{"outline":1.5}}`,
	}
	if !slices.Equal(lines, want) {
		t.Fatalf("history = %q", lines)
	}
	if got := readFile(t, path); len(got) != 2 {
		t.Fatalf("picks.json keeps the current state: %v", got)
	}
	counts, err := s.Changes()
	if err != nil || counts["demo:k"] != 2 || counts["demo:tune"] != 1 {
		t.Fatalf("counts = %v, %v", counts, err)
	}
	if filepath.Base(s.history) != "picks.jsonl" {
		t.Errorf("history file = %s", s.history)
	}
}

func TestHistoryRotatesAtTheCapAndNeverBlocksTheWrite(t *testing.T) {
	s, path := newTestStore(t)
	s.maxHistory = 200
	tick := 0
	s.now = func() time.Time { tick++; return time.Date(2026, 11, 20, 4, 5, 6, tick, time.UTC) }
	for n := range 9 {
		if err := s.Update(fmt.Sprintf("demo:k%d", n), setEntry("A", "")); err != nil {
			t.Fatalf("write %d = %v", n, err)
		}
	}
	if got := readFile(t, path); len(got) != 9 {
		t.Fatalf("%d keys in picks.json, want all 9", len(got))
	}
	if data, _ := s.History(); len(data) == 0 || len(data) > 200 {
		t.Fatalf("current history is %d bytes, cap 200", len(data))
	}
	aside, err := filepath.Glob(filepath.Join(filepath.Dir(path), "picks-*.jsonl"))
	if err != nil || len(aside) != 2 || !strings.HasPrefix(filepath.Base(aside[0]), "picks-20261120T040506") {
		t.Fatalf("rotated files = %v, %v", aside, err)
	}
	lines := 0
	for _, f := range append(aside, s.history) {
		data, err := os.ReadFile(f)
		if err != nil {
			t.Fatal(err)
		}
		lines += strings.Count(string(data), "\n")
	}
	if lines != 9 {
		t.Fatalf("%d history lines over %d files, want 9", lines, len(aside)+1)
	}
}

func TestKeyCapCountsPerRoundPrefix(t *testing.T) {
	s, _ := newTestStore(t)
	s.maxKeys = 2
	for _, key := range []string{"one:a", "one:b", "two:a", "two:b"} {
		if err := s.Update(key, setEntry("A", "")); err != nil {
			t.Fatalf("%s = %v", key, err)
		}
	}
	err := s.Update("one:c", setEntry("A", ""))
	if !errors.Is(err, ErrFull) || !strings.Contains(err.Error(), "2 keys per round") {
		t.Fatalf("third key of round one = %v, want ErrFull naming the limit", err)
	}
}

func TestWriteAtomicSyncsTheDirectoryAfterTheRename(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "picks.json")
	var synced string
	orig := syncDir
	syncDir = func(d string) error {
		if _, err := os.Stat(path); err != nil {
			t.Errorf("directory synced before the rename: %v", err)
		}
		synced = d
		return orig(d)
	}
	t.Cleanup(func() { syncDir = orig })
	if err := writeAtomic(path, []byte(`{}`)); err != nil {
		t.Fatal(err)
	}
	if synced != dir {
		t.Fatalf("synced %q, want %q", synced, dir)
	}
}

func TestHistoryIsEmptyBeforeTheFirstWrite(t *testing.T) {
	s, _ := newTestStore(t)
	if data, err := s.History(); err != nil || len(data) != 0 {
		t.Fatalf("history = %q, %v", data, err)
	}
}
