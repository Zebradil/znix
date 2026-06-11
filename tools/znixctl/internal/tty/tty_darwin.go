//go:build darwin

package tty

import "golang.org/x/sys/unix"

const ioctlGet = unix.TIOCGETA
const ioctlSet = unix.TIOCSETA
