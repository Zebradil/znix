_: {
  flake.modules.homeManager.scripts = _: {
    home.file.".local/bin" = {
      # Path literal store-copies only assets/bin, so the derivation hash depends
      # solely on that subtree — not the whole flake source. Avoids cache busts
      # when unrelated tracked files (renovate.json, .claude/*, .serena/*) change.
      source = ../../assets/bin;
      recursive = true;
    };
  };
}
