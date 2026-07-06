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

      # Integrated home: sweep every home module (minus the Linux GUI apps) plus
      # this user's standalone profile. The same profile backs the standalone
      # homeConfigurations."glashevich@trv4250".
      home-manager.useGlobalPkgs = true;
      home-manager.users."${username}" = {
        imports =
          (builtins.attrValues (
            removeAttrs self.modules.homeManager [
              "firefox"
              "telegram"
              "slack"
            ]
          ))
          ++ [
            self.modules.generic.home-glashevich
          ];
      };

      users.users."${username}" = {
        name = "${username}";
        home = "/Users/${username}";
        shell = pkgs.zsh;
      };
      programs.zsh.enable = true;
    };
}
