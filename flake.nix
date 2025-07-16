{
  description = "My Darwin system + Home Manager flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/45d495d75a58c7dd896dfdfe3f6c2002b7ca64d5";

    flake-utils.url = "github:numtide/flake-utils";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    gke-kubeconfiger = {
      url = "github:Zebradil/gke-kubeconfiger";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };

    mac-app-util.url = "github:hraban/mac-app-util";
  };

  outputs =
    {
      flake-utils,
      gke-kubeconfiger,
      home-manager,
      homebrew-bundle,
      homebrew-cask,
      homebrew-core,
      mac-app-util,
      nix-darwin,
      nix-homebrew,
      nix-index-database,
      nixpkgs,
      self,
    }:
    let
      home-manager-user-configuration =
        {
          pkgs,
          user,
        }:
        (import ./home-manager {
          inherit
            gke-kubeconfiger
            nix-index-database
            pkgs
            user
            ;
        });
    in
    {
      darwinConfigurations = (
        import ./hosts/darwin {
          inherit
            home-manager
            home-manager-user-configuration
            homebrew-bundle
            homebrew-cask
            homebrew-core
            nix-darwin
            nix-homebrew
            nixpkgs
            self
            ;
        }
      );

      homeConfigurations =
        let
          user = "zebradil";
          pkgs = import nixpkgs {
            system = "x86_64-linux";
            config.allowUnfree = true;
          };
        in
        {
          ${user} = home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            modules = [
              (home-manager-user-configuration {
                inherit
                  pkgs
                  user
                  ;
              })
            ];
          };
        };
    };
}
