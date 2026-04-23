{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      checks.actionlint = pkgs.runCommand "actionlint"
        {
          nativeBuildInputs = [
            pkgs.actionlint
            pkgs.shellcheck
          ];
        }
        ''
          actionlint -color ${inputs.self}/.github/workflows/*.y*ml
          shellcheck ${inputs.self}/.github/scripts/*.sh
          touch $out
        '';
    };
}
