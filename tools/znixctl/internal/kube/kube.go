package kube

import (
	"bytes"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strconv"
	"strings"
)

// SignalErr is returned by Signal when kubectl polling fails.
// Callers should treat this as "not caught up" (i.e. use sentinel 9999).
type SignalErr struct{ Err error }

func (e *SignalErr) Error() string { return fmt.Sprintf("signal snapshot: %v", e.Err) }

// Signal returns (pending pods) + (non-terminal not-Ready pods) cluster-wide.
// On any kubectl failure, returns 9999 + SignalErr so a bad poll never looks "caught up".
func Signal() (int, error) {
	pendingOut, err := output(exec.Command("kubectl", "get", "pods", "-A",
		"--field-selector=status.phase=Pending",
		"-o", "go-template={{len .items}}"))
	if err != nil {
		return 9999, &SignalErr{Err: err}
	}
	pending, err := strconv.Atoi(strings.TrimSpace(pendingOut))
	if err != nil {
		return 9999, &SignalErr{Err: err}
	}

	tmpl := `{{range .items}}{{range .status.conditions}}{{if and (eq .type "Ready") (ne .status "True")}}x{{"\n"}}{{end}}{{end}}{{end}}`
	notReadyOut, err := output(exec.Command("kubectl", "get", "pods", "-A",
		"--field-selector=status.phase!=Succeeded,status.phase!=Failed",
		"-o", "go-template="+tmpl))
	if err != nil {
		return 9999, &SignalErr{Err: err}
	}
	notReady := 0
	for _, line := range strings.Split(notReadyOut, "\n") {
		if strings.TrimSpace(line) != "" {
			notReady++
		}
	}
	return pending + notReady, nil
}

// Cordon runs `kubectl cordon <node>`. Output is forwarded to stdout/stderr.
func Cordon(node string) error {
	c := exec.Command("kubectl", "cordon", node)
	c.Stdout = os.Stdout
	c.Stderr = os.Stderr
	return c.Run()
}

// DrainResult tells the caller whether the node was drained or simply gone.
type DrainResult int

const (
	DrainOK DrainResult = iota
	DrainNotFound
)

// Drain runs `kubectl drain --delete-emptydir-data --ignore-daemonsets <node>`,
// tee'ing combined output to stdout. If kubectl exits non-zero AND output
// contains "NotFound"/"not found", returns DrainNotFound, nil (autoscaler race).
func Drain(node string) (DrainResult, error) {
	c := exec.Command("kubectl", "drain", "--delete-emptydir-data", "--ignore-daemonsets", node)
	var buf bytes.Buffer
	c.Stdout = io.MultiWriter(os.Stdout, &buf)
	c.Stderr = io.MultiWriter(os.Stdout, &buf)
	err := c.Run()
	if err == nil {
		return DrainOK, nil
	}
	out := buf.String()
	if strings.Contains(out, "NotFound") || strings.Contains(out, "not found") {
		return DrainNotFound, nil
	}
	return DrainOK, fmt.Errorf("kubectl drain %s: %w", node, err)
}

// ProviderInfo extracts project and zone from a node's .spec.providerID.
// providerID format: gce://<project>/<zone>/<instance>
func ProviderInfo(node string) (project, zone string, err error) {
	out, err := output(exec.Command("kubectl", "get", "node", node,
		"-o", "jsonpath={.spec.providerID}"))
	if err != nil {
		return "", "", fmt.Errorf("kubectl get node %s providerID: %w", node, err)
	}
	parts := strings.Split(strings.TrimSpace(out), "/")
	if len(parts) < 5 {
		return "", "", fmt.Errorf("unexpected providerID %q for %s", out, node)
	}
	return parts[2], parts[3], nil
}

func output(c *exec.Cmd) (string, error) {
	var out, errBuf bytes.Buffer
	c.Stdout = &out
	c.Stderr = &errBuf
	if err := c.Run(); err != nil {
		return "", fmt.Errorf("%s: %w (stderr: %s)", strings.Join(c.Args, " "), err, strings.TrimSpace(errBuf.String()))
	}
	return out.String(), nil
}
