{ ... }:
{
  # ─ HTTP / REST client ─────────────────────────────────────────
  # kulala: pure-lua REST client for .http / .rest files (curl backend).
  plugins.kulala = {
    enable = true;
    settings = {
      display_mode = "split";
      split_direction = "vertical";
      default_view = "body";
      default_env = "dev";
    };
  };

  # Map .http / .rest extensions to the `http` filetype so kulala and the
  # treesitter http grammar (see plugins-core.nix) kick in.
  filetype.extension = {
    http = "http";
    rest = "http";
  };
}
