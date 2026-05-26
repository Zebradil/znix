package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
	"github.com/zebradil/znix/tools/znixctl/internal/version"
)

var rootCmd = &cobra.Command{
	Use:           "znixctl",
	Short:         "znix multitool",
	Long:          "znixctl bundles operational tools migrated from shell scripts.",
	Version:       version.Short(),
	SilenceUsage:  true,
	SilenceErrors: true,
}

func init() {
	rootCmd.SetVersionTemplate("{{.Version}}\n")
}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
