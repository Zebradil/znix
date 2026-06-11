package tty

import (
	"os"
	"time"

	"golang.org/x/sys/unix"
)

// TTY wraps /dev/tty with minimal termios changes for single-key input.
// Only ICANON and ECHO are cleared; OPOST/ISIG/IEXTEN are left intact so that
// \n→\r\n translation and signal keys (Ctrl-C) continue to work normally.
// If Open fails (e.g. no TTY attached) callers may pass nil — methods are nil-safe.
type TTY struct {
	f    *os.File
	fd   int
	oldT *unix.Termios
	ch   chan byte
}

func Open() (*TTY, error) {
	f, err := os.OpenFile("/dev/tty", os.O_RDWR, 0)
	if err != nil {
		return nil, err
	}
	fd := int(f.Fd())

	old, err := unix.IoctlGetTermios(fd, ioctlGet)
	if err != nil {
		_ = f.Close()
		return nil, err
	}
	newT := *old
	newT.Lflag &^= unix.ICANON | unix.ECHO
	newT.Cc[unix.VMIN] = 1
	newT.Cc[unix.VTIME] = 0
	if err := unix.IoctlSetTermios(fd, ioctlSet, &newT); err != nil {
		_ = f.Close()
		return nil, err
	}

	t := &TTY{f: f, fd: fd, oldT: old, ch: make(chan byte, 8)}
	go t.readLoop()
	return t, nil
}

// readLoop feeds bytes from the tty into ch. Exits when the fd is closed.
func (t *TTY) readLoop() {
	var buf [1]byte
	for {
		n, err := unix.Read(t.fd, buf[:])
		if err != nil || n == 0 {
			return
		}
		t.ch <- buf[0]
	}
}

func (t *TTY) Close() {
	if t == nil {
		return
	}
	if t.oldT != nil {
		_ = unix.IoctlSetTermios(t.fd, ioctlSet, t.oldT)
	}
	_ = t.f.Close()
}

// ReadKey waits up to timeout for a single byte. Empty string on timeout.
// If t is nil, sleeps the full timeout and returns "".
func (t *TTY) ReadKey(timeout time.Duration) (string, error) {
	if t == nil {
		time.Sleep(timeout)
		return "", nil
	}
	select {
	case b := <-t.ch:
		return string([]byte{b}), nil
	case <-time.After(timeout):
		return "", nil
	}
}

// WaitKey blocks indefinitely for one key. Returns "" if t is nil.
func (t *TTY) WaitKey() (string, error) {
	if t == nil {
		return "", nil
	}
	b := <-t.ch
	return string([]byte{b}), nil
}
