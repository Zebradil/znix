{ ... }:
{
  flake.modules.homeManager.neovim =
    {
      pkgs,
      config,
      ...
    }:
    let
      base = {
        # Symlink the AstroNvim config into the nv profile directory
        # Access via: nv astro
        xdg.configFile."nvim-profiles/astro/nvim".source =
          config.znix.mkRepoLink "modules/home/editors/neovim/nvim";

        # Plain neovim binary for profile switching via the nv script.
        # The default nvim is nixCats (wrapRc=true, ignores XDG overrides),
        # so profiles need an unwrapped neovim that respects XDG_CONFIG_HOME.
        home.packages = [
          (pkgs.writeShellScriptBin "nvim-profile" ''
            exec ${pkgs.neovim-unwrapped}/bin/nvim "$@"
          '')
        ];
      };
    in
    base;
}
