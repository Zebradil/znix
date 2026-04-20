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
    {
      imports = [ inputs.nixvim.homeModules.nixvim ];

      config = lib.mkMerge [
        {
          programs.nixvim = import ./_config { inherit pkgs inputs lib; };
          home.packages = [ pkgs.tree-sitter ];
        }
        { programs.nixvim.nixpkgs.useGlobalPackages = true; }
        (lib.mkIf osConfig.znix.impermanence.enable {
          home.persistence."/persist".directories = [ ".config/github-copilot" ];
        })
      ];
    };
}
