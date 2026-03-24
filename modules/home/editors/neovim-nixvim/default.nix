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
      nvim = inputs.nixvim.legacyPackages.${pkgs.stdenv.hostPlatform.system}.makeNixvimWithModule {
        inherit pkgs;
        module = import ./_config.nix;
        extraSpecialArgs = { inherit inputs; };
      };

      base = {
        home.packages = [
          pkgs.tree-sitter
          (pkgs.writeShellScriptBin "nvx" ''
            exec ${nvim}/bin/nvim "$@"
          '')
        ];
      };
      #
      # impermanence = lib.mkIf osConfig.znix.impermanence.enable {
      #   home.persistence."/persist".directories = [ ".config/github-copilot" ];
      # };
    in
    lib.mkMerge [
      base
      # impermanence
    ];
}
