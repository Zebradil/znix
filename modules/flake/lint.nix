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
              # The only self-test dependency stdenv does not already provide.
              pkgs.jq
            ];
          }
          ''
            actionlint -color ${inputs.self}/.github/workflows/*.y*ml
            shellcheck ${inputs.self}/.github/scripts/*.sh

            # assets/bin takes whatever scripts land there, so lint by shebang
            # rather than by glob -- a python helper must not break the check.
            for f in ${inputs.self}/assets/bin/*; do
              if head -n1 "$f" | grep -qE '^#!.*\b(ba)?sh$'; then
                shellcheck "$f"
              fi
            done

            bash ${inputs.self}/assets/bin/kubectl-inventory --self-test
            touch $out
          '';
    };
}
