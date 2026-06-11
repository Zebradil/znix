package version

import "fmt"

var (
	Version = "dev"
	Commit  = "unknown"
	Dirty   = "false" // set via ldflags; "true" => built from dirty tree
	Date    = ""
)

func IsDirty() bool { return Dirty == "true" }

// Short is the one-line string used by cobra's --version flag.
func Short() string {
	c := Commit
	if len(c) > 12 {
		c = c[:12]
	}
	if IsDirty() {
		c += "-dirty"
	}
	return fmt.Sprintf("%s (%s)", Version, c)
}

// Long is the multi-line string printed by the version subcommand.
func Long() string {
	dirty := ""
	if IsDirty() {
		dirty = " (dirty)"
	}
	out := fmt.Sprintf("znixctl %s\ncommit: %s%s\n", Version, Commit, dirty)
	if Date != "" {
		out += fmt.Sprintf("built:  %s\n", Date)
	}
	return out
}
