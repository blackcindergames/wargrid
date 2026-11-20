//go:build !linux

package main

import "errors"

func dropPrivileges(string, int) error { return errors.New("WARROOM_RUN_AS needs Linux") }
