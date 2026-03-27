{ inputs, lib, ... }:
{
  flake-file.inputs = {
    gke-kubeconfiger = {
      url = "github:Zebradil/gke-kubeconfiger";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tree-sitter-queries.url = "github:zebradil/tree-sitter-queries";
    tree-sitter-test_highlights.url = "github:zebradil/tree-sitter-test_highlights";
    tree-sitter-ytt_annotation.url = "github:zebradil/tree-sitter-ytt_annotation";
  };

  flake.overlays.default = lib.composeManyExtensions [
    inputs.tree-sitter-queries.overlays.default
    inputs.tree-sitter-test_highlights.overlays.default
    inputs.tree-sitter-ytt_annotation.overlays.default
    (final: _prev: {
      inherit (inputs.gke-kubeconfiger.packages.${final.stdenv.hostPlatform.system}) gke-kubeconfiger;
    })
  ];
}
