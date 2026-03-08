{ ... }:
{
  flake.modules.homeManager.google-cloud-sdk =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        (google-cloud-sdk.withExtraComponents [ google-cloud-sdk.components.gke-gcloud-auth-plugin ])
      ];
    };
}
