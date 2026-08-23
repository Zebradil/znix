{ ... }:
{
  znix.workarounds.dictd-db-eng2rus = {
    package = "dictdDBs.eng2rus";
    systems = [ "aarch64-darwin" ];
    reason = "dictdDBs.eng2rus is a data-only package but claims meta.platforms = linux, so it refuses to evaluate on Darwin.";
    override = _pkgs: old: {
      meta = old.meta // {
        platforms = old.meta.platforms ++ [ "aarch64-darwin" ];
      };
    };
  };
}
