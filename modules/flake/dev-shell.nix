{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    {
      devShells.default = pkgs.mkShell {
        packages = [
          inputs.colmena.packages.${system}.colmena # fleet deploy: `colmena apply --on <host>`
        ]
        ++ (with pkgs; [
          actionlint
          age
          shellcheck
          sops
          ssh-to-age
          nixfmt
          vendir
        ]);
      };
    };
}
