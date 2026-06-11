//go:build linux

package tty

import "golang.org/x/sys/unix"

const ioctlGet = unix.TCGETS
const ioctlSet = unix.TCSETS
