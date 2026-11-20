package store

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"time"
)

const (
	// Per round prefix, so one full round never stops the others from recording.
	maxKeys   = 500
	maxKeyLen = 160
	// Past this the history file is renamed aside and a new one started, so no write is ever refused for it.
	maxHistory = 64 << 20
)

var (
	ErrBadKey = errors.New("bad picks key")
	ErrFull   = errors.New("picks file is full")

	// A var so a test can check it runs after the rename.
	syncDir = fsyncDir

	keyRE = regexp.MustCompile(`^[a-z0-9-]+:[A-Za-z0-9._:-]+$`)
)

type Entry struct {
	Pick *string `json:"pick"`
	Note string  `json:"note"`
	// Value is a tune step's recorded knobs, param id to number or string.
	Value map[string]any `json:"value,omitempty"`
	// Name is the picked option's name at pick time, so a later edit of the step cannot change what an old letter meant.
	Name string `json:"name,omitempty"`
}

// Store is the picks file: one mutex around read-modify-write, atomic replace on write.
// Beside it, the history file keeps one JSON line per change.
type Store struct {
	path       string
	history    string
	mu         sync.Mutex
	maxKeys    int
	maxHistory int64
	now        func() time.Time
	write      func(path string, data []byte) error
}

func NewStore(path string) *Store {
	return &Store{
		path: path, history: strings.TrimSuffix(path, filepath.Ext(path)) + ".jsonl",
		maxKeys: maxKeys, maxHistory: maxHistory, now: time.Now, write: writeAtomic,
	}
}

// Close waits for a write in progress and keeps the lock, so no write is cut short or started before the process exits.
func (s *Store) Close() { s.mu.Lock() }

type historyLine struct {
	T   string `json:"t"`
	Key string `json:"key"`
	Entry
}

// Entries returns every entry; an unreadable file or one of another shape is an error.
func (s *Store) Entries() (map[string]Entry, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	raw, err := s.load()
	if err != nil {
		return nil, err
	}
	out := make(map[string]Entry, len(raw))
	for k, v := range raw {
		var e Entry
		if err := json.Unmarshal(v, &e); err != nil {
			return nil, fmt.Errorf("%s: entry %q: %w", s.path, k, err)
		}
		out[k] = e
	}
	return out, nil
}

// Update replaces the entry for key with change(old entry); a new key past its round's cap is ErrFull.
func (s *Store) Update(key string, change func(Entry) Entry) error {
	if len(key) > maxKeyLen || !keyRE.MatchString(key) {
		return ErrBadKey
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	raw, err := s.load()
	if err != nil {
		return err
	}
	var old Entry
	prev, exists := raw[key]
	if exists {
		if err = json.Unmarshal(prev, &old); err != nil {
			return fmt.Errorf("%s: entry %q: %w", s.path, key, err)
		}
	} else if keysWithPrefix(raw, key) >= s.maxKeys {
		return fmt.Errorf("%w: %d keys per round", ErrFull, s.maxKeys)
	}
	next := change(old)
	enc, err := json.Marshal(next)
	if err != nil {
		return err
	}
	// The history goes first: a crash between the two leaves a line for a write the state never saw, not the reverse.
	err = s.appendHistory(key, old, next, exists)
	if err != nil {
		return err
	}
	raw[key] = enc
	out, err := marshalIndented(raw)
	if err != nil {
		return err
	}
	return s.write(s.path, out)
}

func keysWithPrefix(raw map[string]json.RawMessage, key string) int {
	prefix, _, _ := strings.Cut(key, ":")
	n := 0
	for k := range raw {
		if strings.HasPrefix(k, prefix+":") {
			n++
		}
	}
	return n
}

// appendHistory adds one fsynced line; a write that changes nothing adds none.
func (s *Store) appendHistory(key string, old, next Entry, exists bool) error {
	if exists {
		a, _ := json.Marshal(old)
		b, _ := json.Marshal(next)
		if bytes.Equal(a, b) {
			return nil
		}
	}
	line, err := json.Marshal(historyLine{T: s.now().UTC().Format(time.RFC3339), Key: key, Entry: next})
	if err != nil {
		return err
	}
	line = append(line, '\n')
	err = os.MkdirAll(filepath.Dir(s.history), 0o750)
	if err != nil {
		return err
	}
	err = s.rotateIfFull(int64(len(line)))
	if err != nil {
		return err
	}
	f, err := os.OpenFile(s.history, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o600)
	if err != nil {
		return err
	}
	return writeSynced(f, line)
}

// rotateIfFull renames the history aside as <name>-<UTC time>.jsonl when the next line would pass the cap.
func (s *Store) rotateIfFull(next int64) error {
	st, err := os.Stat(s.history)
	if errors.Is(err, os.ErrNotExist) || (err == nil && st.Size()+next <= s.maxHistory) {
		return nil
	}
	if err != nil {
		return err
	}
	// Nanoseconds: a rename onto an existing name would replace that file.
	stamp := s.now().UTC().Format("20060102T150405.000000000Z")
	err = os.Rename(s.history, strings.TrimSuffix(s.history, ".jsonl")+"-"+stamp+".jsonl")
	if err != nil {
		return err
	}
	return syncDir(filepath.Dir(s.history))
}

// History is the raw history file; none yet is empty.
func (s *Store) History() ([]byte, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	data, err := os.ReadFile(s.history)
	if errors.Is(err, os.ErrNotExist) {
		return nil, nil
	}
	return data, err
}

// Changes counts the history lines per key.
func (s *Store) Changes() (map[string]int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	counts := map[string]int{}
	f, err := os.Open(s.history)
	if errors.Is(err, os.ErrNotExist) {
		return counts, nil
	}
	if err != nil {
		return nil, err
	}
	defer func() { _ = f.Close() }()
	sc := bufio.NewScanner(f)
	// A line holds at most a 4000-character note, JSON-escaped, and a 1 KiB tune value.
	sc.Buffer(nil, 1<<20)
	for sc.Scan() {
		var h struct {
			Key string `json:"key"`
		}
		if json.Unmarshal(sc.Bytes(), &h) == nil && h.Key != "" {
			counts[h.Key]++
		}
	}
	return counts, sc.Err()
}

// load keeps entries as raw JSON so a rewrite never drops fields it does not know.
func (s *Store) load() (map[string]json.RawMessage, error) {
	data, err := os.ReadFile(s.path)
	if errors.Is(err, os.ErrNotExist) {
		return map[string]json.RawMessage{}, nil
	}
	if err != nil {
		return nil, err
	}
	var raw map[string]json.RawMessage
	if err := json.Unmarshal(data, &raw); err != nil {
		return nil, fmt.Errorf("%s: %w", s.path, err)
	}
	// A hand-seeded file of another shape would be overwritten unseen on the next pick.
	for k, v := range raw {
		if !bytes.HasPrefix(bytes.TrimSpace(v), []byte("{")) {
			return nil, fmt.Errorf("%s: entry %q is not an object", s.path, k)
		}
	}
	if raw == nil {
		return nil, fmt.Errorf("%s: not an object of entries", s.path)
	}
	return raw, nil
}

func marshalIndented(raw map[string]json.RawMessage) ([]byte, error) {
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false)
	enc.SetIndent("", " ")
	if err := enc.Encode(raw); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func writeAtomic(path string, data []byte) error {
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0o750); err != nil {
		return err
	}
	tmp, err := os.CreateTemp(dir, ".picks-*.tmp")
	if err != nil {
		return err
	}
	if err := writeSynced(tmp, data); err != nil {
		_ = os.Remove(tmp.Name())
		return err
	}
	if err := os.Rename(tmp.Name(), path); err != nil {
		_ = os.Remove(tmp.Name())
		return err
	}
	// Without it a power loss can undo the rename although the file's data was synced.
	return syncDir(dir)
}

func fsyncDir(dir string) error {
	d, err := os.Open(dir)
	if err != nil {
		return err
	}
	err = d.Sync()
	if cerr := d.Close(); err == nil {
		err = cerr
	}
	return err
}

func writeSynced(f *os.File, data []byte) error {
	_, err := f.Write(data)
	if err == nil {
		err = f.Sync()
	}
	if cerr := f.Close(); err == nil {
		err = cerr
	}
	return err
}
