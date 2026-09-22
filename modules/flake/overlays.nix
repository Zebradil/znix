{
  config,
  inputs,
  lib,
  ...
}:
{
  flake-file.inputs = {
    gke-kubeconfiger = {
      url = "github:Zebradil/gke-kubeconfiger";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pr-autopilot = {
      url = "github:Zebradil/pr-autopilot";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sofka = {
      url = "github:nklmilojevic/sofka";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tree-sitter-queries.url = "github:zebradil/tree-sitter-queries";
    tree-sitter-test_highlights.url = "github:zebradil/tree-sitter-test_highlights";
    tree-sitter-ytt_annotation.url = "github:zebradil/tree-sitter-ytt_annotation";
  };

  # Permanent additions first, then the workaround overlay assembled from
  # modules/flake/workarounds/ — see docs/workarounds.md. Everything in the
  # latter is temporary and probed weekly for removal.
  flake.overlays.default = lib.composeManyExtensions [
    inputs.sofka.overlays.default
    inputs.tree-sitter-queries.overlays.default
    inputs.tree-sitter-test_highlights.overlays.default
    inputs.tree-sitter-ytt_annotation.overlays.default
    (final: _prev: {
      inherit (inputs.gke-kubeconfiger.packages.${final.stdenv.hostPlatform.system}) gke-kubeconfiger;
      inherit (inputs.pr-autopilot.packages.${final.stdenv.hostPlatform.system}) pr-autopilot;
    })
    # claude-code releases faster than nixpkgs tracks it. The upstream
    # derivation reads version and per-platform checksums from `manifest`, so a
    # newer release is a manifest swap, nothing more. Once nixpkgs catches up the
    # pin throws rather than silently holding an old version back — the failure
    # is the reminder to delete this block or bump the manifest.
    #
    # Refresh: curl -fsSL https://downloads.claude.ai/claude-code-releases/latest
    # then .../claude-code-releases/$VERSION/manifest.zst.json
    (_final: prev: {
      claude-code =
        let
          manifest = {
            version = "2.1.280";
            platforms = {
              darwin-arm64 = {
                binary = "claude.zst";
                checksum = "214fafd9d60bc0397cb68747b765ab752be4b53303c176ad885c4cafbe30826f";
              };
              linux-arm64 = {
                binary = "claude.zst";
                checksum = "6a01f30418f35122a672ccf74bed64aba5119ad47c71548a3b447cc9fec48c81";
              };
              linux-x64 = {
                binary = "claude.zst";
                checksum = "27910e2ae704d8f2e8024897d8fdf1e7710807baf4f6982c0e3797c058315384";
              };
            };
          };
        in
        if lib.versionOlder prev.claude-code.version manifest.version then
          prev.claude-code.override { inherit manifest; }
        else
          throw "claude-code: nixpkgs is at ${prev.claude-code.version}, pin in modules/flake/overlays.nix is ${manifest.version} — bump the manifest or delete the block";
    })
    config.flake.overlays.workarounds
  ];
}
