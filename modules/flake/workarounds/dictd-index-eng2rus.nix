_: {
  workarounds.dictd-index-eng2rus = {
    package = "dictdDBs.eng2rus";
    reason = "The eng-rus.index that dictdDBs.eng2rus ships is not sorted in dictd's collation, so its binary search misses exact lookups at random.";
    override = pkgs: old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.dict ];
      postFixup = (old.postFixup or "") + ''
        dictfmt -I < $out/share/dictd/eng-rus.index > "$TMPDIR/eng-rus.index"
        mv "$TMPDIR/eng-rus.index" $out/share/dictd/eng-rus.index
      '';
    };
    fixed =
      pkgs:
      let
        index = "${pkgs.dictdDBs.eng2rus}/share/dictd/eng-rus.index";
      in
      pkgs.runCommand "dictd-index-eng2rus-sorted" { nativeBuildInputs = [ pkgs.dict ]; } ''
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
