#!/usr/bin/env bash
# Exit 0 when the generation selected for next boot differs from the booted one
# in a part only a reboot applies; exit 1 otherwise. kured runs it as its
# reboot sentinel (docs/adr/0008-k3s-rolling-reboots.md).
# Usage: k3s-reboot-required [NEXT_SYSTEM [BOOTED_SYSTEM]]
set -euo pipefail

next=${1:-/nix/var/nix/profiles/system}
booted=${2:-/run/booted-system}

for part in kernel initrd kernel-modules systemd; do
  if [[ $(readlink -m "$booted/$part") != $(readlink -m "$next/$part") ]]; then
    echo "reboot required: $part differs"
    exit 0
  fi
done
exit 1
