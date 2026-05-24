{ inputs, ... }:
let
  cavemanOptionsModule =
    { lib, ... }:
    {
      options.znix.claude.caveman = {
        enable = lib.mkEnableOption "caveman hooks for claude profiles";
        profiles = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Profile names (keys of znix.claude.profiles) that get caveman deployed";
        };
      };
    };
in
{
  flake-file.inputs.caveman = {
    url = "github:JuliusBrussee/caveman";
    flake = false;
  };

  flake.modules = {
    nixos.claude-caveman = cavemanOptionsModule;
    darwin.claude-caveman = cavemanOptionsModule;

    homeManager.claude-caveman =
      {
        lib,
        osConfig,
        pkgs,
        config,
        ...
      }:
      let
        cavemanCfg =
          osConfig.znix.claude.caveman or {
            enable = false;
            profiles = [ ];
          };
        allProfiles = osConfig.znix.claude.profiles or { };
        enabled = lib.filterAttrs (
          n: p: p.enable && cavemanCfg.enable && lib.elem n cavemanCfg.profiles
        ) allProfiles;

        cavemanSrc = inputs.caveman;
        znixStatusline = "${osConfig.znix.claude.assetsRoot}/statusline-command.sh";

        mkDirFiles =
          profile: srcDir: destDir:
          lib.mapAttrs' (
            entryName: _type:
            lib.nameValuePair "${profile.configDir}/${destDir}/${entryName}" {
              source = "${srcDir}/${entryName}";
            }
          ) (builtins.readDir srcDir);

        mkComposedStatusline =
          profile:
          pkgs.writeShellScript "claude-${profile.command}-statusline-with-caveman" ''
            set -uo pipefail
            input=$(cat)
            znix_out=$(printf '%s' "$input" | bash ${znixStatusline})
            caveman_out=$(printf '%s' "$input" | bash "$HOME/${profile.configDir}/hooks/caveman-statusline.sh" || true)
            if [ -n "$caveman_out" ]; then
              printf '%s %s' "$znix_out" "$caveman_out"
            else
              printf '%s' "$znix_out"
            fi
          '';
      in
      lib.mkIf (cavemanCfg.enable && enabled != { }) {
        home.packages = [ pkgs.nodejs ];

        home.file = lib.mkMerge (
          lib.mapAttrsToList (
            _: profile:
            (mkDirFiles profile "${cavemanSrc}/src/hooks" "hooks")
            // (mkDirFiles profile "${cavemanSrc}/skills" "skills")
            // (mkDirFiles profile "${cavemanSrc}/commands" "commands")
            // {
              "${profile.configDir}/statusline-command.sh".source = lib.mkForce (mkComposedStatusline profile);
            }
          ) enabled
        );
      };
  };
}
