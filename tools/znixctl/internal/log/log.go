package log

import (
	"fmt"
	"os"
	"os/exec"
)

// Talk controls whether Say() invokes macOS `say`.
var Talk = os.Getenv("TALK") == "true"

func Err(format string, a ...any)     { fmt.Fprintf(os.Stderr, "\x1b[1;31m[✗] "+format+"\x1b[0m\r\n", a...) }
func Info(format string, a ...any)    { fmt.Fprintf(os.Stdout, "\x1b[1;93m[‼︎] "+format+"\x1b[0m\r\n", a...) }
func Success(format string, a ...any) { fmt.Fprintf(os.Stdout, "\x1b[1;32m[✔] "+format+"\x1b[0m\r\n", a...) }

// Say speaks the message via macOS `say` if Talk is enabled. Non-blocking; errors ignored.
func Say(msg string) {
	if !Talk {
		return
	}
	c := exec.Command("say", msg)
	_ = c.Start()
	go func() { _ = c.Wait() }()
}
