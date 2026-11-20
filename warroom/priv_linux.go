package main

import (
	"errors"
	"os"
	"path/filepath"
	"syscall"
)

// dropPrivileges hands the picks directory to uid and drops root before serving; Fly mounts the volume root-owned.
func dropPrivileges(picks string, uid int) error {
	if os.Geteuid() != 0 {
		return errors.New("WARROOM_RUN_AS is set but the process is not root")
	}
	for _, p := range []string{filepath.Dir(picks), picks} {
		if err := os.Chown(p, uid, uid); err != nil && !errors.Is(err, os.ErrNotExist) {
			return err
		}
	}
	if err := syscall.Setgroups(nil); err != nil {
		return err
	}
	if err := syscall.Setgid(uid); err != nil {
		return err
	}
	return syscall.Setuid(uid)
}
