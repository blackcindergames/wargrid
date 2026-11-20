package store

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sync"
)

const (
	// Public URL: caps what an anonymous client can grow the volume to.
	maxKeys   = 500
	maxKeyLen = 160
)

var (
	ErrBadKey = errors.New("bad picks key")
	ErrFull   = errors.New("picks file is full")

	keyRE = regexp.MustCompile(`^[a-z0-9-]+:[A-Za-z0-9._:-]+$`)
)

type Entry struct {
	Pick *string `json:"pick"`
	Note string  `json:"note"`
	// Value is a tune step's recorded knobs, param id to number or string.
	Value map[string]any `json:"value,omitempty"`
}

// Store is the picks file: one mutex around read-modify-write, atomic replace on write.
type Store struct {
	path    string
	mu      sync.Mutex
	maxKeys int
	write   func(path string, data []byte) error
}

func NewStore(path string) *Store {
	return &Store{path: path, maxKeys: maxKeys, write: writeAtomic}
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

// Update replaces the entry for key with change(old entry); a new key past the cap is ErrFull.
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
	} else if len(raw) >= s.maxKeys {
		return ErrFull
	}
	enc, err := json.Marshal(change(old))
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
	return nil
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
