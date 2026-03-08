{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          age
          sops
          ssh-to-age
          nixfmt
        ];
      };
    };
}
