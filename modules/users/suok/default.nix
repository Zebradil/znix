_: {
  # Lean admin user for the toddler appliance. No home-manager, no password:
  # SSH key login + sudo via ssh-agent (security.pam.sshAgentAuth, enabled by
  # the shared openssh module). Reuses the zebradil SSH public key.
  # See docs/adr/0001-toddler-appliance-host.md.
  flake.modules.nixos.suok =
    { pkgs, lib, ... }:
    {
      users.mutableUsers = false;
      users.users.suok = {
        isNormalUser = true;
        shell = pkgs.bash;
        extraGroups = [
          "wheel" # sudo (passwordless via ssh-agent)
          "dialout" # ANT+ USB access for manual blebridge testing
        ];
        openssh.authorizedKeys.keys = lib.splitString "\n" (builtins.readFile ../zebradil/ssh.pub);
      };
    };
}
