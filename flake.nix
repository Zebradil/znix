{
  description = "My Darwin system + Home Manager flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    flake-utils.url = "github:numtide/flake-utils";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/0.1";

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

  outputs = {
    determinate,
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
  }: let
    home-manager-user-configuration = {
      pkgs,
      user,
    }: (
      import ./home-manager {
        inherit
          gke-kubeconfiger
          mac-app-util
          nix-index-database
          pkgs
          user
          ;
      }
    );
  in {
    darwinConfigurations = (
      import ./hosts/darwin.nix {
        inherit
          determinate
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
  };
}
