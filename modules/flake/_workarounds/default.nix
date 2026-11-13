# The workarounds framework, exported as flakeModules.workarounds.
# Specification: docs/workarounds.md. Rationale: docs/adr/0007-workarounds-framework.md.
{
  config,
  inputs,
  lib,
  ...
}:
let
  entries = config.workarounds;

  # null means every system the flake builds for.
  systemsOf = w: if w.systems == null then config.systems else w.systems;
  appliesTo = system: w: builtins.elem system (systemsOf w);
  onSystem = system: ws: lib.filterAttrs (_: appliesTo system) ws;

  # The option types cannot express "exactly one of", so kindOf enforces it. It
  # is forced from checks.<system>.workarounds, which `nix flake check` builds.
  kindOf =
    name: w:
    let
      set = lib.filter (k: k.on) [
        {
          kind = "pin";
          on = w.pin != null;
        }
        {
          kind = "override";
          on = w.override != null;
        }
        {
          kind = "module";
          on = w.module != { };
        }
      ];
      inherit (lib.head set) kind;
    in
    if lib.length set != 1 then
      throw "workaround ${name}: set exactly one of `pin`, `override`, `module`"
    else if kind == "module" && w.package != null then
      throw "workaround ${name}: `package` only applies to `pin` and `override`"
    else if kind == "module" && w.fixed == null then
      throw "workaround ${name}: a `module` entry must set `fixed`"
    else
      kind;

  isPackageKind =
    name: w:
    builtins.elem (kindOf name w) [
      "pin"
      "override"
    ];
  packageOf = name: w: if w.package == null then name else w.package;

  # `package` is an attribute path: "mise", "dictdDBs.eng2rus", or
  # "linuxKernel.packages.linux_xanmod_latest.tuxedo-drivers".
  pathOf = lib.splitString ".";
  getPkg = pkgs: package: lib.getAttrFromPath (pathOf package) pkgs;

  # A pinned nixpkgs is re-imported, so its config module re-runs against what
  # we hand it. prev.config is the *evaluated* config: it carries every option
  # default, and any option whose type changed between revisions breaks eval.
  # Forward only the plain user-intent options a pin needs.
  userIntentConfig = lib.filterAttrs (
    n: _:
    builtins.elem n [
      "allowUnfree"
      "allowUnfreePredicate"
      "permittedInsecurePackages"
    ]
  );

  # Entries on one package stack in a fixed order: the pin chooses the base,
  # then every override folds on top in name order. `current` is the package as
  # its enclosing scope sees it, which inside an extensible package set is not
  # the same as getPkg pkgs.
  apply =
    pkgs: package: current: ws:
    let
      pins = lib.filterAttrs (name: w: kindOf name w == "pin") ws;
      overrides = lib.filterAttrs (name: w: kindOf name w == "override") ws;
      base =
        if pins == { } then
          current
        else if lib.length (lib.attrNames pins) > 1 then
          throw "package ${package}: pinned by ${lib.concatStringsSep " and " (lib.attrNames pins)}, but a package takes at most one pin"
        else
          getPkg (import inputs.${(lib.head (lib.attrValues pins)).pin} {
            inherit (pkgs.stdenv.hostPlatform) system;
            config = userIntentConfig pkgs.config;
          }) package;
    in
    lib.foldl' (pkg: w: pkg.overrideAttrs (w.override pkgs)) base (lib.attrValues overrides);

  # The overlay for a set of entries, filtered to the platform it is applied on.
  mkOverlay =
    ws: _final: prev:
    let
      byPackage = lib.groupBy (name: packageOf name ws.${name}) (
        lib.attrNames (lib.filterAttrs isPackageKind (onSystem prev.stdenv.hostPlatform.system ws))
      );
      # The packages as a tree of attribute paths, each leaf naming its package.
      tree = lib.foldl' (
        acc: package: lib.recursiveUpdate acc (lib.setAttrByPath (pathOf package) { __package = package; })
      ) { } (lib.attrNames byPackage);
      # An overlay's attrset is merged into prev with `//`, which is shallow, so
      # returning `{ dictdDBs = { eng2rus = ...; }; }` would drop every other
      # dictdDB: each intermediate attrset is rebuilt from the original. An
      # extensible one (a kernel package set) goes through `extend` instead:
      # NixOS re-extends boot.kernelPackages, which discards a `//` update, and
      # the package has to come from `super` to be built against the kernel
      # NixOS overrides in that same set.
      patch =
        node:
        lib.mapAttrs (
          name: sub:
          if sub ? __package then
            apply prev sub.__package node.${name} (lib.getAttrs byPackage.${sub.__package} ws)
          else if node.${name} ? extend then
            node.${name}.extend (_: super: patch super sub)
          else
            node.${name} // patch node.${name} sub
        );
    in
    patch prev tree;

  # Probe pkgs: candidate nixpkgs with every *other* entry still applied. The
  # probe workflow runs `nix flake update` first, so inputs.nixpkgs is already
  # the candidate. allowUnfree, or an unfree package fails its licence check,
  # which reads the same as "still broken".
  probePkgs =
    system: name:
    import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = [ (mkOverlay (removeAttrs entries [ name ])) ];
    };

  fixedOf =
    name: w:
    if w.fixed != null then
      w.fixed
    else if isPackageKind name w then
      pkgs: getPkg pkgs (packageOf name w)
    else
      throw "workaround ${name}: no probe";

  registry = lib.mapAttrs (name: w: {
    kind = kindOf name w;
    package = if isPackageKind name w then packageOf name w else null;
    systems = systemsOf w;
    inherit (w) file reason;
  }) entries;

  # Fragments are not gated by `systems`: a gate would need pkgs inside mkIf,
  # which recurses for fragments that touch nixpkgs.*. `systems` picks where a
  # module entry is probed.
  classModule = class: {
    _file = ./default.nix;
    imports = lib.mapAttrsToList (_: w: {
      _file = w.file;
      imports = [ w.module.${class} ];
    }) (lib.filterAttrs (_: w: w.module ? ${class}) entries);
  };
in
{
  options.workarounds = lib.mkOption {
    description = ''
      Temporary changes that make up for something broken upstream, one entry
      per file. Every entry declares a probe that builds once it is no longer
      needed. See docs/workarounds.md.
    '';
    default = { };
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }:
        {
          options = {
            reason = lib.mkOption {
              type = lib.types.str;
              description = "One line on what is broken upstream; quoted in the removal PR.";
            };
            systems = lib.mkOption {
              type = lib.types.nullOr (lib.types.listOf lib.types.str);
              default = null;
              description = "Systems the breakage affects; null means every system the flake builds for.";
            };
            package = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Attribute path a `pin` or `override` replaces; defaults to the entry name.";
            };
            pin = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Flake input holding a nixpkgs revision where the package works.";
            };
            override = lib.mkOption {
              type = lib.types.nullOr lib.types.raw;
              default = null;
              description = "`pkgs: old: attrs`, passed to overrideAttrs.";
            };
            module = lib.mkOption {
              type = lib.types.attrsOf lib.types.raw;
              default = { };
              description = "Modules keyed by class: nixos, darwin, homeManager.";
            };
            fixed = lib.mkOption {
              type = lib.types.nullOr lib.types.raw;
              default = null;
              description = "`pkgs: drv` that builds only once the entry is no longer needed.";
            };
            file = lib.mkOption {
              type = lib.types.str;
              default = "modules/flake/workarounds/${name}.nix";
              description = "Repo-relative path the removal PR deletes.";
            };
          };
        }
      )
    );
  };

  config = {
    flake = {
      overlays.workarounds = mkOverlay entries;

      modules = lib.genAttrs [ "nixos" "darwin" "homeManager" ] (class: {
        workarounds = classModule class;
      });

      workarounds = {
        inherit registry;
        probes = lib.genAttrs config.systems (
          system: lib.mapAttrs (name: w: fixedOf name w (probePkgs system name)) (onSystem system entries)
        );
      };
    };

    perSystem =
      { pkgs, ... }:
      let
        tool = pkgs.writeShellApplication {
          name = "workarounds";
          # nix itself comes from the runner, so the CLI matches its daemon.
          runtimeInputs = [
            pkgs.gh
            pkgs.git
            pkgs.jq
          ];
          text = builtins.readFile ./workarounds.sh;
        };
      in
      {
        apps.workarounds = {
          type = "app";
          program = lib.getExe tool;
          meta.description = "Probe workarounds and propose their removal";
        };

        # Interpolating the registry forces every entry's validation at eval time.
        checks.workarounds = pkgs.runCommand "workarounds-check" { } ''
          : ${lib.escapeShellArg (builtins.toJSON registry)}
          ${lib.getExe tool} self-test
          touch $out
        '';
      };
  };
}
