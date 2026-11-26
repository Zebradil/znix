_: {
  # Builder load the node exporter cannot see on its own, written for its
  # textfile collector: SSH store sessions per user, builds in progress and
  # connections sshd refused. Answers whether CI fan-out hits daddy's limits.
  flake.modules.nixos.daddy-builder-metrics =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      dir = "/run/node-exporter-textfile";
      users = [
        "nixci"
        "nixremote"
      ];
      collect = pkgs.writeShellApplication {
        name = "builder-metrics";
        runtimeInputs = [
          config.systemd.package
          pkgs.coreutils
          pkgs.gawk
          pkgs.procps
        ];
        text = ''
          state="$STATE_DIRECTORY"
          tmp="$(mktemp -p ${dir})"
          trap 'rm -f "$tmp"' EXIT

          # sshd logs one line per refused connection, but rate-limits them and
          # reports the skipped ones as "<reason> logging rate-limited:
          # additional N connections dropped". Totals survive in the state
          # file; the cursor makes every run read only new lines.
          [ -f "$state/drops" ] || printf '0 0\n' >"$state/drops"
          read -r maxstartups penalties <"$state/drops"
          read -r maxstartups penalties < <(
            journalctl --unit sshd.service --cursor-file "$state/cursor" --output cat --quiet --no-pager |
              awk -v m="$maxstartups" -v p="$penalties" '
                /^drop connection #/ { if (/ MaxStartups$/) m++; else p++ }
                /^MaxStartups logging rate-limited: additional [0-9]+ / { m += $5 }
                /^PerSourcePenalties logging rate-limited: additional [0-9]+ / { p += $5 }
                END { print m, p }
              '
          )
          printf '%s %s\n' "$maxstartups" "$penalties" >"$state/drops.new"
          mv "$state/drops.new" "$state/drops"

          {
            echo '# HELP nix_builder_ssh_sessions Open SSH store sessions (nix-daemon --stdio processes) per user.'
            echo '# TYPE nix_builder_ssh_sessions gauge'
            for u in ${toString users}; do
              echo "nix_builder_ssh_sessions{user=\"$u\"} $(pgrep -c -x -u "$u" nix-daemon || true)"
            done
            echo '# HELP nix_builder_active_builds Build users running a process, one per build in progress.'
            echo '# TYPE nix_builder_active_builds gauge'
            echo "nix_builder_active_builds $({ ps -G nixbld -o uid= || true; } | sort -u | wc -l)"
            echo '# HELP sshd_dropped_connections_total Connections sshd refused before authentication, by reason.'
            echo '# TYPE sshd_dropped_connections_total counter'
            echo "sshd_dropped_connections_total{reason=\"MaxStartups\"} $maxstartups"
            echo "sshd_dropped_connections_total{reason=\"PerSourcePenalties\"} $penalties"
          } >"$tmp"
          chmod 0644 "$tmp"
          mv "$tmp" ${dir}/builder.prom
        '';
      };
    in
    {
      services.prometheus.exporters.node.extraFlags = [ "--collector.textfile.directory=${dir}" ];

      systemd.tmpfiles.rules = [ "d ${dir} 0755 root root -" ];

      systemd.services.builder-metrics = {
        description = "Builder metrics for the node exporter";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe collect;
          StateDirectory = "builder-metrics";
          Nice = 19;
        };
      };
      systemd.timers.builder-metrics = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "15s";
          OnUnitActiveSec = "15s";
          AccuracySec = "1s";
        };
      };
    };
}
