_: {
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
    };
}
