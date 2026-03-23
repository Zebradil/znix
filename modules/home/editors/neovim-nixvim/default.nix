{ inputs, ... }:
{
  flake-file.inputs = {
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
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

      impermanence = lib.mkIf osConfig.znix.impermanence.enable {
        home.persistence."/persist".directories = [ ".config/github-copilot" ];
      };
    in
    lib.mkMerge [
      base
      impermanence
    ];
}
