{ ... }:
{
  znix.workarounds.mise-darwin-tests = {
    package = "mise";
    systems = [ "aarch64-darwin" ];
    reason = "mise's oci::layer::tests::preserve_metadata_dir_layer_keeps_special_permission_bits fails on Darwin.";
    override = _: _: {
      doCheck = false;
    };
  };
}
