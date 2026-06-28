{ inputs, lib, ... }:
let
  # ===========================================================
  # Package pins — edit here to pin packages to specific refs.
  # See docs/package-pins.md for the full workflow.
  #
  # Shorthand (all systems):   pkgname = "github:NixOS/nixpkgs/<rev>";
  # Long form (per-system):    pkgname = { ref = "github:NixOS/nixpkgs/<rev>"; systems = [ "aarch64-darwin" ]; };
  pins = {
    mise = {
      # 2026.6.11 builds from source (not cached) and its new test
      # oci::layer::tests::preserve_metadata_dir_layer_keeps_special_permission_bits
      # fails: expects mode 0o4755 (setuid) but the Nix build sandbox strips the
      # setuid bit, yielding 0o0755. Pin to 2026.6.0 (cached on all systems).
      ref = "github:NixOS/nixpkgs/9ae611a455b90cf061d8f332b977e387bda8e1ca";
    };
    nushell = {
      # Upgrade to 0.112.2 is not in nixpkgs-unstable yet
      ref = "github:NixOS/nixpkgs/e787d9e711e78599f0ad3ec517fcef8192efd47e";
      systems = [ "aarch64-darwin" ];
    };
    google-cloud-sdk = {
      # 570.0.0 bumped bundled-python to 3.14.5, breaking auto-patchelf:
      # libpython3.14.so.1.0 unresolvable via $ORIGIN, and tcl/tk 9.0 not in nixpkgs.
      # Pin to 565.0.0 (bundled-python 3.13.11) until upstream fixes components.nix.
      ref = "github:NixOS/nixpkgs/be8205a2a0bab0384deca31042b9b940fbcf24aa";
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
      name: _:
      (import inputs.${inputName name} {
        system = prev.stdenv.hostPlatform.system;
        # prev.config is the *evaluated* config: it carries every option default
        # (rewriteURL, replaceStdenv, assertions, ...). Re-importing a pinned
        # nixpkgs re-runs its config module against it, and any option whose type
        # changed between revs (e.g. rewriteURL) breaks eval. Forward only the
        # plain user-intent options the pins actually need.
        config = lib.filterAttrs (
          n: _:
          builtins.elem n [
            "allowUnfree"
            "allowUnfreePredicate"
            "permittedInsecurePackages"
          ]
        ) prev.config;
      }).${name}
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
