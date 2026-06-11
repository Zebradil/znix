package cmd

import (
	"bufio"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/spf13/cobra"

	"github.com/zebradil/znix/tools/znixctl/internal/gcp"
	"github.com/zebradil/znix/tools/znixctl/internal/kube"
	"github.com/zebradil/znix/tools/znixctl/internal/log"
	"github.com/zebradil/znix/tools/znixctl/internal/tty"
)

type drainOpts struct {
	cordon       bool
	delete       bool
	dryRun       bool
	adaptive     bool
	noAdaptive   bool
	minWait      int
	maxWait      int
	pollInterval int
	stableFor    int
	tolerance    int
}

var drainArgs drainOpts

var drainNodesCmd = &cobra.Command{
	Use:   "drain-nodes",
	Short: "Drain Kubernetes nodes one by one with adaptive wait",
	Long: `Drain nodes in the cluster one by one. The node list is read from standard input.

By default, an adaptive wait is used between drains: the script polls the cluster
state and proceeds as soon as evicted pods are rescheduled, or falls back to the
--max-wait ceiling. Use --no-adaptive for a fixed sleep instead.

If the TALK environment variable is set to "true", the script will talk to you.

Interactive controls during any wait:
  p   pause the timer (paused time is excluded from max-wait and stable-for)
  s   skip the current wait and proceed to the next node immediately
  any other key   print remaining time and current signal

Input:
  List of nodes to drain, one node per line.

Examples:
  drain-nodes <<< $(printf "node1\nnode2\nnode3")
  kubectl get node -o custom-columns=:.metadata.name --no-headers -l=pool=general \
      | drain-nodes --cordon
  drain-nodes --delete --max-wait 600
  drain-nodes --delete --no-adaptive --max-wait 180`,
	SilenceUsage:  true,
	SilenceErrors: true,
	RunE:          runDrainNodes,
}

func init() {
	f := drainNodesCmd.Flags()
	f.BoolVar(&drainArgs.cordon, "cordon", false, "Cordon all nodes before draining any")
	f.BoolVar(&drainArgs.delete, "delete", false, "Delete nodes from their managed instance group after draining")
	f.BoolVar(&drainArgs.dryRun, "dry-run", false, "Print actions without executing; skip all waits")
	f.BoolVar(&drainArgs.adaptive, "adaptive", true, "Enable adaptive wait between drains (default)")
	f.BoolVar(&drainArgs.noAdaptive, "no-adaptive", false, "Use a fixed sleep of --max-wait seconds instead")
	f.IntVar(&drainArgs.minWait, "min-wait", 20, "Grace period before probing starts")
	f.IntVar(&drainArgs.maxWait, "max-wait", 300, "Hard ceiling on wait time per node")
	f.IntVar(&drainArgs.pollInterval, "poll-interval", 5, "Seconds between cluster state polls in adaptive mode")
	f.IntVar(&drainArgs.stableFor, "stable-for", 15, "Signal must stay at-or-below baseline for this many consecutive seconds")
	f.IntVar(&drainArgs.tolerance, "tolerance", 2, "Allow baseline+N Pending/NotReady pods when deciding caught up")

	rootCmd.AddCommand(drainNodesCmd)
}

func runDrainNodes(cmd *cobra.Command, _ []string) error {
	o := drainArgs
	if o.noAdaptive {
		o.adaptive = false
	}
	if o.minWait < 0 {
		return fmt.Errorf("--min-wait requires a non-negative integer")
	}
	if o.maxWait <= 0 {
		return fmt.Errorf("--max-wait requires a positive integer")
	}
	if o.pollInterval <= 0 {
		return fmt.Errorf("--poll-interval requires a positive integer")
	}
	if o.stableFor < 0 {
		return fmt.Errorf("--stable-for requires a non-negative integer")
	}
	if o.tolerance < 0 {
		return fmt.Errorf("--tolerance requires a non-negative integer")
	}

	log.Info("Reading node list from the standard input")
	nodes, err := readNodes(os.Stdin)
	if err != nil {
		return err
	}

	t, ttyErr := tty.Open()
	if ttyErr != nil {
		log.Info("tty unavailable (%v); interactive controls disabled", ttyErr)
	}
	defer t.Close()

	if o.cordon {
		log.Info("Cordon nodes")
		log.Say("Cordon nodes")
		for _, n := range nodes {
			if o.dryRun {
				log.Info("Dry run: Cordon node %s", n)
				continue
			}
			if err := kube.Cordon(n); err != nil {
				return err
			}
		}
	}

	baseline := 0
	if o.adaptive && !o.dryRun && len(nodes) > 1 {
		log.Info("Capturing cluster baseline ...")
		s, sErr := kube.Signal()
		baseline = s
		if sErr != nil {
			log.Err("baseline snapshot failed: %v (using %d)", sErr, baseline)
		}
		log.Info("Baseline signal: %d (Pending + not-Ready non-terminal pods)", baseline)
	}

	for i, n := range nodes {
		nID := fmt.Sprintf("%d/%d: %s", i+1, len(nodes), n)
		if o.dryRun {
			log.Info("Dry run: Draining node %s", nID)
			if o.delete {
				log.Info("Dry run: Deleting node %s", nID)
			}
			log.Success("Node %s is drained", nID)
			if i == len(nodes)-1 {
				break
			}
			continue
		}

		log.Info("Draining node %s", nID)
		log.Say("Draining node")
		res, err := kube.Drain(n)
		if err != nil {
			return err
		}
		if res == kube.DrainNotFound {
			log.Info("Node %s is already gone (likely deleted by the cluster autoscaler); skipping", n)
			continue
		}

		if o.delete {
			project, zone, err := kube.ProviderInfo(n)
			if err != nil {
				return err
			}
			group := migGroup(n)
			log.Info("Deleting node %s from %s/%s/%s group", n, project, zone, group)
			log.Say("Deleting node")
			dr, err := gcp.DeleteInstance(project, zone, group, n)
			if err != nil {
				return err
			}
			if dr == gcp.DeleteAlreadyDeleting {
				log.Info("Node %s is already being deleted (likely by the cluster autoscaler); skipping", n)
			}
		}

		log.Success("Node %s is drained", nID)

		if i == len(nodes)-1 {
			break
		}

		if o.adaptive {
			doAdaptiveWait(o, baseline, t)
		} else {
			doFixedWait(o, t)
		}
	}

	log.Say("All nodes are drained")
	log.Success("All nodes are drained")
	return nil
}

func readNodes(r *os.File) ([]string, error) {
	var nodes []string
	scanner := bufio.NewScanner(r)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line != "" {
			nodes = append(nodes, line)
		}
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}
	return nodes, nil
}

// migGroup mirrors bash `${node%-*}-grp`.
func migGroup(node string) string {
	if i := strings.LastIndex(node, "-"); i >= 0 {
		return node[:i] + "-grp"
	}
	return node + "-grp"
}

func doAdaptiveWait(o drainOpts, baseline int, t *tty.TTY) {
	start := time.Now()
	deadline := start.Add(time.Duration(o.maxWait) * time.Second)
	target := baseline + o.tolerance
	var stableSince time.Time

	log.Info("Adaptive wait: min=%ds max=%ds stable-for=%ds tolerance=%d target=%d",
		o.minWait, o.maxWait, o.stableFor, o.tolerance, target)
	log.Say("Waiting for cluster to catch up")

	// min-wait phase
	minDeadline := start.Add(time.Duration(o.minWait) * time.Second)
	pollDur := time.Duration(o.pollInterval) * time.Second
	for time.Now().Before(minDeadline) {
		remaining := time.Until(minDeadline)
		waitFor := pollDur
		if remaining < waitFor {
			waitFor = remaining
		}
		if waitFor <= 0 {
			break
		}
		key := waitForKey(t, waitFor)
		switch key {
		case "p":
			elapsed := pause(t)
			minDeadline = minDeadline.Add(elapsed)
			deadline = deadline.Add(elapsed)
		case "s":
			log.Info("Skipped")
			return
		case "":
			// timeout, continue
		default:
			log.Info("min-wait: %.0fs before probing  [p=pause s=skip]", time.Until(minDeadline).Seconds())
		}
	}

	// probing phase
	for {
		now := time.Now()
		if !now.Before(deadline) {
			signal, _ := kube.Signal()
			log.Info("adaptive: deadline reached after %ds (signal=%d target=%d) — raise --max-wait if cluster needs more time",
				o.maxWait, signal, target)
			return
		}
		signal, _ := kube.Signal()
		if signal <= target {
			if stableSince.IsZero() {
				stableSince = now
			}
			if now.Sub(stableSince) >= time.Duration(o.stableFor)*time.Second {
				saved := int(time.Until(deadline).Seconds())
				log.Success("adaptive: caught up — signal=%d target=%d; saved %ds vs max-wait", signal, target, saved)
				log.Say("Cluster caught up")
				return
			}
		} else {
			stableSince = time.Time{}
		}

		stableSecs := 0
		if !stableSince.IsZero() {
			stableSecs = int(now.Sub(stableSince).Seconds())
		}
		leftSecs := int(time.Until(deadline).Seconds())
		log.Info("adaptive: signal=%d target=%d stable=%d/%ds left=%ds  [p=pause s=skip]",
			signal, target, stableSecs, o.stableFor, leftSecs)

		key := waitForKey(t, pollDur)
		switch key {
		case "p":
			elapsed := pause(t)
			deadline = deadline.Add(elapsed)
			if !stableSince.IsZero() {
				stableSince = stableSince.Add(elapsed)
			}
		case "s":
			log.Info("Skipped")
			return
		}
	}
}

func doFixedWait(o drainOpts, t *tty.TTY) {
	deadline := time.Now().Add(time.Duration(o.maxWait) * time.Second)
	log.Info("Fixed wait: %ds  [p=pause s=skip]", o.maxWait)
	log.Say("Waiting")
	for {
		left := time.Until(deadline)
		if left <= 0 {
			return
		}
		key := waitForKey(t, left)
		switch key {
		case "p":
			elapsed := pause(t)
			deadline = deadline.Add(elapsed)
		case "s":
			return
		}
	}
}

// waitForKey waits up to d for a keypress, printing an in-place countdown every second.
// Returns the key pressed, or "" on timeout.
func waitForKey(t *tty.TTY, d time.Duration) string {
	end := time.Now().Add(d)
	for {
		left := time.Until(end)
		if left <= 0 {
			fmt.Fprintf(os.Stdout, "\r\x1b[K")
			return ""
		}
		chunk := time.Second
		if left < chunk {
			chunk = left
		}
		fmt.Fprintf(os.Stdout, "\r\x1b[K    next poll in %.0fs  [p=pause s=skip]", left.Seconds())
		key, _ := t.ReadKey(chunk)
		if key != "" {
			fmt.Fprintf(os.Stdout, "\r\x1b[K")
			return key
		}
	}
}

func pause(t *tty.TTY) time.Duration {
	pauseStart := time.Now()
	log.Info("Paused — press any key to continue")
	_, _ = t.WaitKey()
	fmt.Print("\r\n")
	elapsed := time.Since(pauseStart)
	log.Info("Resumed")
	return elapsed
}
