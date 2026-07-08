_: {
  flake.modules.homeManager.mise =
    { pkgs, ... }:
    {
      programs.mise = {
        enable = true;
        # oci::layer::tests::preserve_metadata_dir_layer_keeps_special_permission_bits fails on Darwin
        package = pkgs.mise.overrideAttrs (_: {
          doCheck = false;
        });
        globalConfig = {
          settings = {
            github.credential_command = "${pkgs.gh}/bin/gh auth token";
          };
        };
      };
    };
}
