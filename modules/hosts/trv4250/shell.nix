_:
let
  darwinModule =
    { lib, ... }:
    {
      options.znix.hosts.trv4250.enable = lib.mkEnableOption "trv4250 host-specific shell config";
    };

  homeModule =
    {
      lib,
      osConfig,
      ...
    }:
    {
      config = lib.mkIf (osConfig.znix.hosts.trv4250.enable or false) {
        programs.zsh = {
          shellAliases = {
            personal-firefox = "screen -dmS personal-firefox /Applications/Firefox.app/Contents/MacOS/firefox -P personal -no-remote";
          };
          initContent = lib.mkOrder 1500 (builtins.readFile ./shell.zsh);
        };
      };
    };
in
{
  flake.modules.darwin.trv4250-shell = darwinModule;
  flake.modules.homeManager.trv4250 = homeModule;
}
