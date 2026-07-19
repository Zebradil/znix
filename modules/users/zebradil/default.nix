{ self, ... }:
{
  flake.modules.nixos.zebradil =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
    in
    {
      users.mutableUsers = false;
      users.users.zebradil = {
        isNormalUser = true;
        shell = pkgs.zsh;
        extraGroups = ifTheyExist [
          "audio"
          "docker"
          "git"
          "i2c"
          "libvirtd"
          "network"
          "plugdev"
          "podman"
          "tss"
          "video"
          "wheel"
          "wireshark"
        ];

        openssh.authorizedKeys.keys = lib.splitString "\n" (builtins.readFile ./ssh.pub);
        hashedPasswordFile = config.sops.secrets.password.path;
        packages = [ pkgs.home-manager ];
      };

      # Home persistence is system-owned. Current impermanence does ALL home
      # bind-mounting in its NixOS module (its home-manager.nix is validation-only);
      # so the mounts must be declared system-side. Rather than hand-copy the dir
      # list (partly COMPUTED — claude persists each profile's configDir, opencode
      # several dirs — so a hand list silently drifts), source it from the single
      # source of truth: the standalone home config's aggregated home.persistence.
      # Reading a string list forces home OPTION eval only, never a home build, so
      # the fast home-switch loop is unaffected; nixos-rebuild is needed only when
      # the persisted-dir SET changes (rare).
      environment.persistence."/persist".users.zebradil = lib.mkIf config.znix.impermanence.enable {
        directories =
          self.homeConfigurations."zebradil@tuxedo".config.home.persistence."/persist".directories;
      };

      # Ephemeral root wipes $HOME every boot. Standalone home-manager (unlike the
      # integrated NixOS module) installs no boot activation unit, so nothing
      # recreates the dotfile symlinks. Without hyprland.conf at first launch, GDM
      # runs Hyprland config-less and it writes an autogen hyprland.lua that then
      # shadows HM's config (Hyprland 0.55 is lua-first). Ordering before
      # display-manager restores the baked generation first; requiredBy makes a
      # failed activation block GDM (fail to a TTY, recoverable) instead of letting
      # it start config-less and corrupt the persisted Hyprland config.
      #
      # Referencing activationPackage builds the home at nixos-rebuild time;
      # `home-manager switch` stays the fast iterate loop.
      #
      # ponytail: activate's `systemctl --user` reloads run late (no user bus yet)
      # — fine, only the symlinks are on the critical path. Revisit if a home
      # service must be live before the compositor.
      systemd.services.home-manager-zebradil = lib.mkIf config.znix.impermanence.enable {
        description = "Activate zebradil's home-manager generation at boot";
        wantedBy = [ "multi-user.target" ];
        before = [ "display-manager.service" ];
        requiredBy = [ "display-manager.service" ];
        after = [
          "local-fs.target"
          "nix-daemon.socket"
        ];
        # activate self-supplies coreutils; only needs nix on PATH for the
        # user-environment realisation (nix-build/nix-env).
        path = [ config.nix.package ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "zebradil";
          Environment = [
            "HOME=/home/zebradil"
            "USER=zebradil"
          ];
        };
        script = "${self.homeConfigurations."zebradil@tuxedo".activationPackage}/activate";
      };

      sops = {
        defaultSopsFile = ../../../secrets/users/zebradil.yaml;
        secrets = {
          password.neededForUsers = true;
          "u2f_keys/${config.networking.hostName}" = lib.mkIf config.znix.fido.enable {
            path = "/home/zebradil/.config/Yubico/u2f_keys";
            owner = "zebradil";
            mode = "0400";
          };
        };
      };
    };
}
