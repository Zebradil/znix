{
  config,
  inputs,
  lib,
  ...
}:
let
  # Systems a probe can be built on. Kept in step by hand with RUNNER_MAPPING in
  # .github/workflows/workaround-probe.yaml — a system listed here with no runner
  # there is warned about by workaround-matrix.sh rather than silently dropped. A
  # workaround with `systems = null` applies to, and is probed on, all of them.
  probeSystems = [
    "x86_64-linux"
    "aarch64-linux"
    "aarch64-darwin"
  ];

  inherit (config.znix) workarounds;

  appliesTo = system: w: w.systems == null || builtins.elem system w.systems;
  systemsOf = w: if w.systems == null then probeSystems else w.systems;

  # A pinned nixpkgs is re-imported, so its config module re-runs against
  # whatever we hand it. prev.config is the *evaluated* config: it carries every
  # option default (rewriteURL, replaceStdenv, assertions, ...), and any option
  # whose type changed between revs breaks eval. Forward only the plain
  # user-intent options a pin actually needs.
  userIntentConfig = lib.filterAttrs (
    n: _:
    builtins.elem n [
      "allowUnfree"
      "allowUnfreePredicate"
      "permittedInsecurePackages"
    ]
  );

  # `pin` and `override` are mutually exclusive, which the option types cannot
  # express. Forced from workaroundRegistry so a malformed entry fails the weekly
  # probe's `nix eval` up front, instead of waiting for a host to build that one
  # package — nothing here reaches `nix flake check`, which skips outputs it does
  # not recognise.
  kindOf =
    name: w:
    if w.pin != null && w.override != null then
      throw "workaround ${name}: set either `pin` or `override`, not both"
    else if w.pin != null then
      "pin"
    else if w.override != null then
      "override"
    else
      throw "workaround ${name}: needs either `pin` or `override`";

  resolve =
    prev: name: w:
    if kindOf name w == "pin" then
      (import inputs.${w.pin} {
        system = prev.stdenv.hostPlatform.system;
        config = userIntentConfig prev.config;
      }).${w.package}
    else
      prev.${w.package}.overrideAttrs (w.override prev);

  # Probes deliberately build vanilla nixpkgs with no overlays: the question they
  # answer is "does upstream work on its own yet?". allowUnfree is required or
  # unfree probes fail on the licence check, which is indistinguishable from the
  # workaround still being needed.
  vanilla =
    system:
    import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
in
{
  options.znix.workarounds = lib.mkOption {
    description = ''
      Temporary replacements for packages broken in nixpkgs, one entry per file
      under modules/flake/workarounds/. Every entry is expected to die: the
      weekly probe builds the vanilla package and opens a removal PR once
      upstream builds it unaided. See docs/workarounds.md.
    '';
    default = { };
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }:
        {
          options = {
            package = lib.mkOption {
              type = lib.types.str;
              default = name;
              description = "nixpkgs attribute this workaround replaces.";
            };

            systems = lib.mkOption {
              type = lib.types.nullOr (lib.types.listOf lib.types.str);
              default = null;
              description = "Systems the breakage affects; null means all of them.";
            };

            file = lib.mkOption {
              type = lib.types.str;
              default = "modules/flake/workarounds/${name}.nix";
              description = "Repo-relative path the removal PR deletes.";
            };

            reason = lib.mkOption {
              type = lib.types.str;
              description = "One line on what is broken upstream; quoted in the removal PR.";
            };

            pin = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Flake input holding a nixpkgs revision where the package works.";
            };

            override = lib.mkOption {
              type = lib.types.nullOr lib.types.raw;
              default = null;
              description = "`pkgs: old: attrs` passed to overrideAttrs.";
            };
          };
        }
      )
    );
  };

  config.flake = {
    overlays.workarounds =
      _final: prev:
      lib.mapAttrs' (name: w: lib.nameValuePair w.package (resolve prev name w)) (
        lib.filterAttrs (_: appliesTo prev.stdenv.hostPlatform.system) workarounds
      );

    workaroundProbes = lib.genAttrs probeSystems (
      system:
      let
        pkgs = vanilla system;
      in
      lib.mapAttrs' (name: w: lib.nameValuePair name pkgs.${w.package}) (
        lib.filterAttrs (_: appliesTo system) workarounds
      )
    );

    # Plain data for CI: the probe matrix and what a removal PR has to delete.
    workaroundRegistry = lib.mapAttrs (
      name: w:
      builtins.seq (kindOf name w) {
        inherit (w) package file reason;
        systems = systemsOf w;
      }
    ) workarounds;
  };
}
