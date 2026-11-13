_: {
  workarounds.dictd-index-wordnet = {
    package = "dictdDBs.wordnet";
    reason = "The wn.index that dictdDBs.wordnet generates is not sorted in dictd's collation, so its binary search misses exact lookups at random.";
    # The package has its own builder and no phases, so the re-sort runs after
    # it; that builder leaves the working directory at $out/share/dictd.
    override = pkgs: old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.dict ];
      builder = pkgs.writeScript "builder.sh" ''
        source ${old.builder}
        dictfmt -I < wn.index > wn.index.sorted
        mv wn.index.sorted wn.index
      '';
    };
    fixed =
      pkgs:
      let
        index = "${pkgs.dictdDBs.wordnet}/share/dictd/wn.index";
      in
      pkgs.runCommand "dictd-index-wordnet-sorted" { nativeBuildInputs = [ pkgs.dict ]; } ''
        dictfmt -I < ${index} > sorted
        # Compare entry order by (offset, length). dictfmt blanks headwords it
        # cannot encode, which moves them to the top, so those are left out.
        awk -F'\t' 'NR == FNR { if ($1 == "") bad[$2 FS $3] = 1; next } !(($2 FS $3) in bad) { print $2, $3 }' \
          sorted ${index} > upstream-order
        awk -F'\t' '$1 != "" { print $2, $3 }' sorted > dictd-order
        cmp -s upstream-order dictd-order
        touch $out
      '';
  };
}
