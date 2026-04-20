{ inputs, lib, ... }:
let
  # ===========================================================
  # Package pins — edit here to pin packages to specific refs.
  # See docs/package-pins.md for the full workflow.
  #
  # Shorthand (all systems):   pkgname = "github:NixOS/nixpkgs/<rev>";
  # Long form (per-system):    pkgname = { ref = "github:NixOS/nixpkgs/<rev>"; systems = [ "aarch64-darwin" ]; };
  pins = {
    nushell = {
      ref = "github:NixOS/nixpkgs/2f1dea39287f84dd1ef8906e578a87505ca9856d";
      systems = [ "aarch64-darwin" ];
    };
  };
  # ===========================================================

  normalize =
    v:
    if builtins.isString v then
      {
        ref = v;
        systems = null;
      }
    else
      { systems = null; } // v;
  normalized = lib.mapAttrs (_: normalize) pins;

  inputName = name: "nixpkgs-pin-${name}";
  appliesTo = system: { systems, ... }: systems == null || builtins.elem system systems;

  pinsOverlay =
    _final: prev:
    lib.mapAttrs (
      name: _: inputs.${inputName name}.legacyPackages.${prev.stdenv.hostPlatform.system}.${name}
    ) (lib.filterAttrs (_: p: appliesTo prev.stdenv.hostPlatform.system p) normalized);
in
{
  flake-file.inputs = {
    gke-kubeconfiger = {
      url = "github:Zebradil/gke-kubeconfiger";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tree-sitter-queries.url = "github:zebradil/tree-sitter-queries";
    tree-sitter-test_highlights.url = "github:zebradil/tree-sitter-test_highlights";
    tree-sitter-ytt_annotation.url = "github:zebradil/tree-sitter-ytt_annotation";
  }
  // lib.mapAttrs' (name: { ref, ... }: lib.nameValuePair (inputName name) { url = ref; }) normalized;

  flake.overlays.default = lib.composeManyExtensions [
    inputs.tree-sitter-queries.overlays.default
    inputs.tree-sitter-test_highlights.overlays.default
    inputs.tree-sitter-ytt_annotation.overlays.default
    (final: _prev: {
      inherit (inputs.gke-kubeconfiger.packages.${final.stdenv.hostPlatform.system}) gke-kubeconfiger;
    })
    pinsOverlay
  ];
}
