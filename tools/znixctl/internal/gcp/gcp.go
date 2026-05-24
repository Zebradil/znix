package gcp

import (
	"bytes"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strings"
)

type DeleteResult int

const (
	DeleteOK DeleteResult = iota
	DeleteAlreadyDeleting
)

// DeleteInstance removes one instance from a managed instance group.
// If the instance is already being deleted (autoscaler race), returns
// DeleteAlreadyDeleting, nil.
func DeleteInstance(project, zone, group, instance string) (DeleteResult, error) {
	c := exec.Command("gcloud", "compute", "instance-groups", "managed", "delete-instances",
		"--project="+project,
		"--zone="+zone,
		"--instances="+instance,
		group)
	var buf bytes.Buffer
	c.Stdout = io.MultiWriter(os.Stdout, &buf)
	c.Stderr = io.MultiWriter(os.Stderr, &buf)
	err := c.Run()
	if err == nil {
		return DeleteOK, nil
	}
	if strings.Contains(buf.String(), "already being deleted") {
		return DeleteAlreadyDeleting, nil
	}
	return 0, fmt.Errorf("gcloud delete-instances %s: %w", instance, err)
}
