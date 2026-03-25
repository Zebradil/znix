{ inputs, ... }:
{
  flake-file.inputs = {
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    "plugins-tree-sitter-test_highlights" = {
      url = "github:zebradil/tree-sitter-test_highlights";
      flake = false;
    };
    "plugins-tree-sitter-ytt_annotation" = {
      url = "github:zebradil/tree-sitter-ytt_annotation";
      flake = false;
    };
    "plugins-tree-sitter-queries" = {
      url = "github:zebradil/tree-sitter-queries";
      flake = false;
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
      base = {
        imports = [ inputs.nixvim.homeModules.nixvim ];
        programs.nixvim = import ./_config.nix { inherit pkgs inputs; };
        home.packages = [ pkgs.tree-sitter ];
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
