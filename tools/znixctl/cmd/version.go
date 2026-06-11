package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
	"github.com/zebradil/znix/tools/znixctl/internal/version"
)

func init() {
	rootCmd.AddCommand(&cobra.Command{
		Use:   "version",
		Short: "Print version, commit, and build metadata",
		Run: func(cmd *cobra.Command, _ []string) {
			fmt.Fprint(cmd.OutOrStdout(), version.Long())
		},
	})
}
