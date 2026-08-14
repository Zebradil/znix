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
              pkgs.shellcheck
              pkgs.jq
              pkgs.python3
            ];
          }
          ''
            actionlint -color ${inputs.self}/.github/workflows/*.y*ml
            shellcheck ${inputs.self}/.github/scripts/*.sh

            # assets/bin takes whatever scripts land there, so lint by shebang
            # rather than by glob -- a python helper must not break the check.
            for f in ${inputs.self}/assets/bin/*; do
              if head -n1 "$f" | grep -qE '^#!.*\b(ba|z)?sh$'; then
                shellcheck "$f"
              fi
            done

            bash ${inputs.self}/assets/bin/kubectl-inventory --self-test
            # Fixtures for both transcript stores: the tripwire for the next
            # Claude Code log change or opencode database migration.
            python3 ${inputs.self}/modules/home/session-export/session-export.py --selftest
            bash ${inputs.self}/.github/scripts/workaround-matrix.sh --self-test
            bash ${inputs.self}/.github/scripts/workaround-propose.sh --self-test
            touch $out
          '';
    };
}
