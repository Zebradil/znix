_: {
  # TODO: extract a tool-agnostic lean-admin base. This user is now shared by
  # toddler and junior, but the name, the toddler-only `dialout` group (ANT+
  # USB) and the toddler-flavoured comment below are appliance-specific — split
  # the reusable core (SSH login, NOPASSWD sudo, CLI toolset) from those.
  #
  # Lean admin user for the toddler appliance. No home-manager, no password:
  # SSH key login (security.pam.sshAgentAuth, enabled by the shared openssh
  # module) + true NOPASSWD sudo via security.sudo.extraRules. Reuses the
  # zebradil SSH public key. See docs/adr/0001-toddler-appliance-host.md.
  flake.modules.nixos.suok =
    { pkgs, lib, ... }:
    {
      users.mutableUsers = false;
      security.sudo.extraRules = [
        {
          users = [ "suok" ];
          commands = [
            {
              command = "ALL";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];
      users.users.suok = {
        isNormalUser = true;
        shell = pkgs.bash;
        extraGroups = [
          "wheel" # sudo group membership (NOPASSWD granted via extraRules above)
          "dialout" # ANT+ USB access for manual blebridge testing
        ];
        openssh.authorizedKeys.keys = lib.splitString "\n" (builtins.readFile ../zebradil/ssh.pub);
      };

      environment.systemPackages = with pkgs; [
        bat
        bind # provides dig, host and nslookup
        btop
        coreutils
        curl
        doggo
        duf
        eza
        fd
        htop
        iperf3
        ncdu
        neovim
        ripgrep
      ];
    };
}
