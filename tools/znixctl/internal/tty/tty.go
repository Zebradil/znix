package tty

import (
	"errors"
	"os"
	"time"

	"golang.org/x/term"
)

// TTY wraps /dev/tty in raw mode for single-key input with deadlines.
// If Open fails (e.g. no TTY attached) callers may pass nil — methods are nil-safe.
type TTY struct {
	f        *os.File
	fd       int
	oldState *term.State
}

func Open() (*TTY, error) {
	f, err := os.OpenFile("/dev/tty", os.O_RDWR, 0)
	if err != nil {
		return nil, err
	}
	fd := int(f.Fd())
	st, err := term.MakeRaw(fd)
	if err != nil {
		_ = f.Close()
		return nil, err
	}
	return &TTY{f: f, fd: fd, oldState: st}, nil
}

func (t *TTY) Close() {
	if t == nil {
		return
	}
	if t.oldState != nil {
		_ = term.Restore(t.fd, t.oldState)
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
	if err := t.f.SetReadDeadline(time.Now().Add(timeout)); err != nil {
		return "", err
	}
	buf := make([]byte, 1)
	n, err := t.f.Read(buf)
	if err != nil {
		if errors.Is(err, os.ErrDeadlineExceeded) {
			return "", nil
		}
		return "", err
	}
	if n == 0 {
		return "", nil
	}
	return string(buf[:n]), nil
}

// WaitKey blocks indefinitely for one key. Returns "" if t is nil.
func (t *TTY) WaitKey() (string, error) {
	if t == nil {
		return "", nil
	}
	if err := t.f.SetReadDeadline(time.Time{}); err != nil {
		return "", err
	}
	buf := make([]byte, 1)
	n, err := t.f.Read(buf)
	if err != nil {
		return "", err
	}
	return string(buf[:n]), nil
}
