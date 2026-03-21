{
  inputs,
  self,
  ...
}:

let
  username = "glashevich";
in
{
  flake.modules.darwin."${username}" =
    { pkgs, ... }:
    {

      imports = with inputs.self.modules.darwin; [
        # videoEditing
      ];

      home-manager.useGlobalPkgs = true;
      home-manager.users."${username}" = {
        imports =
          (builtins.attrValues (
            removeAttrs self.modules.homeManager [
              "firefox"
              "hyprland"
            ]
          ))
          ++ [
            ./_home.nix
          ];
        home = {
          username = "${username}";
          homeDirectory = "/Users/${username}";
          stateVersion = "24.05";
        };
      };

      users.users."${username}" = {
        name = "${username}";
        home = "/Users/${username}";
        shell = pkgs.zsh;
      };
      programs.zsh.enable = true;
    };
}
