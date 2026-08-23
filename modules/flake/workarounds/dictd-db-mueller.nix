{ ... }:
{
  znix.workarounds.dictd-db-mueller = {
    package = "dictdDBs.mueller_eng2rus_pkg";
    systems = [ "aarch64-darwin" ];
    reason = "dictdDBs.mueller_eng2rus_pkg is a data-only package but claims meta.platforms = linux, so it refuses to evaluate on Darwin.";
    override = _pkgs: old: {
      meta = old.meta // {
        platforms = old.meta.platforms ++ [ "aarch64-darwin" ];
      };
    };
  };
}
