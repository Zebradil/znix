{ inputs, ... }:
{
  flake-file.inputs = {
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
  };

  flake.modules.homeManager.neovim-nixvim =
    {
      pkgs,
      lib,
      osConfig,
      ...
    }:
    let
      nvim = inputs.nixvim.legacyPackages.${pkgs.system}.makeNixvimWithModule {
        inherit pkgs;
        module = import ./_config.nix;
        extraSpecialArgs = { inherit inputs; };
      };

      base = {
        home.packages = [
          (pkgs.writeShellScriptBin "nvx" ''
            exec ${nvim}/bin/nvim "$@"
          '')
        ];
      };
    in
    base;
}
