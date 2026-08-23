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

  workaroundsFor = ws: package: lib.filterAttrs (_: w: w.package == package) ws;
  packagesIn = ws: lib.unique (map (w: w.package) (lib.attrValues ws));
  applicableOn = system: lib.filterAttrs (_: appliesTo system) workarounds;

  # `package` is an attribute *path*: "mise" or "dictdDBs.eng2rus". Two levels is
  # the limit, because the overlay has to rebuild the intermediate attrset by
  # hand (below) and each extra level is another layer of that.
  pathOf =
    package:
    let
      parts = lib.splitString "." package;
    in
    if lib.length parts > 2 then
      throw "workaround package ${package}: at most one level of nesting is supported"
    else
      parts;
  getPkg = pkgs: package: lib.getAttrFromPath (pathOf package) pkgs;

  # One package can carry several workarounds — mise needs one to skip a test
  # that fails on Darwin, and another to put back the cmake that skipping drags
  # out of nativeCheckInputs. They stack in a fixed order: the pin chooses the
  # base package, then every override folds on top in name order. Each still
  # dies on its own probe.
  apply =
    pkgs: package: ws:
    let
      pins = lib.filterAttrs (name: w: kindOf name w == "pin") ws;
      overrides = lib.filterAttrs (name: w: kindOf name w == "override") ws;
      base =
        if pins == { } then
          getPkg pkgs package
        else if lib.length (lib.attrNames pins) > 1 then
          throw "package ${package}: pinned by ${lib.concatStringsSep " and " (lib.attrNames pins)}, but a package takes at most one pin"
        else
          getPkg (import inputs.${(lib.head (lib.attrValues pins)).pin} {
            inherit (pkgs.stdenv.hostPlatform) system;
            config = userIntentConfig pkgs.config;
          }) package;
    in
    lib.foldl' (pkg: w: pkg.overrideAttrs (w.override pkgs)) base (lib.attrValues overrides);

  # Probes build from vanilla nixpkgs with no overlays: the question they answer
  # is "does upstream work on its own yet?". allowUnfree is required or unfree
  # probes fail on the licence check, which is indistinguishable from the
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
      weekly probe rebuilds the package without it and opens a removal PR once
      upstream no longer needs the help. See docs/workarounds.md.
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
              description = "nixpkgs attribute this workaround replaces; may be nested one level, as in `dictdDBs.eng2rus`.";
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
      let
        ws = applicableOn prev.stdenv.hostPlatform.system;
        # An overlay's attrset is merged into prev with `//`, which is shallow, so
        # returning `{ dictdDBs = { eng2rus = ...; }; }` would drop every other
        # dictdDB. Group by top-level attribute and rebuild the intermediate
        # attrset from prev.
        byTop = lib.groupBy (package: lib.head (pathOf package)) (packagesIn ws);
      in
      lib.mapAttrs (
        top: packages:
        if packages == [ top ] then
          apply prev top (workaroundsFor ws top)
        else
          prev.${top}
          // lib.listToAttrs (
            map (
              package:
              lib.nameValuePair (lib.last (pathOf package)) (apply prev package (workaroundsFor ws package))
            ) packages
          )
      ) byTop;

    # Leave-one-out: every *other* workaround on the package stays applied, so a
    # probe asks "is this one still pulling its weight?" rather than "is vanilla
    # nixpkgs fine?". The two answers differ whenever a package carries more than
    # one workaround, and only the first is the question worth asking.
    workaroundProbes = lib.genAttrs probeSystems (
      system:
      let
        pkgs = vanilla system;
        ws = applicableOn system;
      in
      lib.mapAttrs (name: w: apply pkgs w.package (removeAttrs (workaroundsFor ws w.package) [ name ])) ws
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
