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
    tree-sitter-test_highlights.url = "github:zebradil/tree-sitter-test_highlights";
  };

  flake.modules.homeManager.neovim-nixvim =
    {
      pkgs,
      lib,
      osConfig,
      ...
    }:
    {
      # imports must be at the module top level, NOT inside lib.mkMerge
      # (mkMerge treats its contents as config values, so imports would be
      # interpreted as a config option rather than a module structural key)
      imports = [ inputs.nixvim.homeModules.nixvim ];

      config = lib.mkMerge [
        {
          programs.nixvim = import ./_config.nix { inherit pkgs inputs; };
          home.packages = [ pkgs.tree-sitter ];
        }
        (lib.mkIf osConfig.znix.impermanence.enable {
          home.persistence."/persist".directories = [ ".config/github-copilot" ];
        })
      ];
    };
}
