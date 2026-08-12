_: {
  flake.modules.homeManager._1password =
    {
      pkgs,
      lib,
      config,
      isDarwin,
      ...
    }:
    let
      onePasswordStartup = pkgs.writeShellApplication {
        name = "1password-startup";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.procps
        ];
        text = ''
          log_dir="${config.xdg.stateHome}/1password"
          mkdir -p "$log_dir"

          if pgrep -x 1password >/dev/null; then
            exit 0
          fi

          # Keep startup observable; current builds can die early on this host.
          exec 1password --silent >>"$log_dir/startup.log" 2>&1
        '';
      };

      base =
        let
          allowedSignersFile = pkgs.writeText "allowed-signers" ''
            ${config.znix.user.email} ${config.sshPublicKey}
          '';
        in
        {
          programs.git = {
            signing = {
              format = "ssh";
              key = config.sshPublicKey;
              signByDefault = true;
              # On darwin _1password-gui ships op-ssh-sign inside the .app
              # bundle, not in $out/bin, so getExe' produces a dead path.
              #
              # On nixos, go through system PATH instead of pkgs._1password-gui:
              # programs._1password-gui patches the polkit policy with
              # polkitPolicyOwners, so the system package is a different
              # derivation than the plain one. Referencing pkgs here would pull a
              # second ~540 MB copy into the home closure.
              signer =
                if isDarwin then
                  "${pkgs._1password-gui}/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
                else
                  "/run/current-system/sw/bin/op-ssh-sign";
            };
            settings."gpg.ssh".allowedSignersFile = toString allowedSignersFile;
          };
        };

      darwin = {
        home.packages = [ pkgs._1password-cli ];
      };

      nixos = {
        programs.ssh.settings."*".IdentityAgent = "~/.1password/agent.sock";
        wayland.windowManager.hyprland.settings.exec-once = [ "${lib.getExe onePasswordStartup}" ];
      };

      impermanence = lib.mkIf config.znix.impermanence.enable {
        home.persistence."/persist".directories = [ ".config/1Password" ];
      };

    in
    lib.mkMerge (
      if isDarwin then
        [
          base
          darwin
        ]
      else
        [
          base
          nixos
          impermanence
        ]
    );

  flake.modules.nixos._1password =
    { config, lib, ... }:
    {
      programs._1password.enable = true;
      programs._1password-gui = {
        enable = true;
        polkitPolicyOwners = builtins.attrNames (lib.filterAttrs (_: u: u.isNormalUser) config.users.users);
      };
    };
}
