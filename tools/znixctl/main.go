package main

import (
	"os"
	"path/filepath"

	"github.com/zebradil/znix/tools/znixctl/cmd"
)

// Known subcommands that can be invoked via basename symlinks
// (e.g. `drain-nodes` -> `znixctl drain-nodes`).
var basenameSubcommands = map[string]bool{
	"drain-nodes": true,
}

func main() {
	base := filepath.Base(os.Args[0])
	if basenameSubcommands[base] {
		os.Args = append([]string{"znixctl", base}, os.Args[1:]...)
	}
	cmd.Execute()
}
