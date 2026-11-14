{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      checks.lint =
        pkgs.runCommand "lint"
          {
            nativeBuildInputs = [
              pkgs.actionlint
              pkgs.git
              pkgs.shellcheck
              pkgs.statix
              pkgs.jq
              pkgs.python3
              pkgs.yq-go
            ];
          }
          ''
            statix check --config ${inputs.self}/statix.toml ${inputs.self}
            actionlint -color ${inputs.self}/.github/workflows/*.y*ml
            shellcheck ${inputs.self}/hack/*.sh

            # assets/bin takes whatever scripts land there, so lint by shebang
            # rather than by glob -- a python helper must not break the check.
            for f in ${inputs.self}/assets/bin/*; do
              if head -n1 "$f" | grep -qE '^#!.*\b(ba|z)?sh$'; then
                shellcheck "$f"
              fi
            done

            bash ${inputs.self}/assets/bin/kubectl-inventory --self-test

            # k3s-reboot-required: identical generations -> 1, new k3s unit -> 0.
            for g in a b c; do
              mkdir -p gen/$g/etc/systemd/system
              for p in kernel initrd kernel-modules systemd; do ln -s /store/$p gen/$g/$p; done
            done
            ln -s /store/k3s-old gen/a/etc/systemd/system/k3s.service
            ln -s /store/k3s-old gen/b/etc/systemd/system/k3s.service
            ln -s /store/k3s-new gen/c/etc/systemd/system/k3s.service
            if bash ${inputs.self}/modules/nixos/k3s-reboot-required.sh gen/b gen/a; then exit 1; fi
            bash ${inputs.self}/modules/nixos/k3s-reboot-required.sh gen/c gen/a
            bash ${inputs.self}/modules/home/alertmanager/am-alerts.sh --self-test
            # Fixtures for all three transcript stores: the tripwire for the next
            # Claude Code log change, Cursor JSONL change, or opencode migration.
            python3 ${inputs.self}/modules/home/session-export/session-export.py --selftest
            touch $out
          '';
    };
}
