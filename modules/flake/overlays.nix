{ inputs, ... }:
{
  flake-file.inputs.gke-kubeconfiger = {
    url = "github:Zebradil/gke-kubeconfiger";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  flake.overlays.default = final: _prev: {
    gke-kubeconfiger = inputs.gke-kubeconfiger.packages.${final.system}.gke-kubeconfiger;
  };
}
