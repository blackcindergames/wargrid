package main

import (
	"errors"
	"os"
	"path/filepath"
	"syscall"
)

const nobody = 65534

// dropPrivileges hands the picks directory to nobody and drops root before serving; Fly mounts the volume root-owned.
func dropPrivileges(picks string) error {
	if os.Geteuid() != 0 {
		return nil
	}
	for _, p := range []string{filepath.Dir(picks), picks} {
		if err := os.Chown(p, nobody, nobody); err != nil && !errors.Is(err, os.ErrNotExist) {
			return err
		}
	}
	if err := syscall.Setgroups(nil); err != nil {
		return err
	}
	if err := syscall.Setgid(nobody); err != nil {
		return err
	}
	return syscall.Setuid(nobody)
}
