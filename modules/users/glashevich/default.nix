{
  inputs,
  ...
}:

let
  username = "glashevich";
in
{
  # System side is account-only; home is deployed standalone via
  # homeConfigurations."glashevich@trv4250" (home-manager switch). Darwin has no
  # impermanence, so nothing from home needs to be mirrored system-side.
  flake.modules.darwin."${username}" =
    { pkgs, ... }:
    {

      imports = with inputs.self.modules.darwin; [
        # videoEditing
      ];

      users.users."${username}" = {
        name = "${username}";
        home = "/Users/${username}";
        shell = pkgs.zsh;
      };
      programs.zsh.enable = true;
    };
}
