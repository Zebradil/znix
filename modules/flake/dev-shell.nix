{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          actionlint
          age
          shellcheck
          sops
          ssh-to-age
          nixfmt
        ];
      };
    };
}
