_: {
  # NixOS-specific overrides for zebradil
  znix.useWritableLinks = false;
  znix.user = {
    name = "German Lashevich";
    email = "german.lashevich@gmail.com";
  };
  sshPublicKey = builtins.readFile ./ssh.pub;
  znix.docker.multiarchBuilder.enable = true;
  znix.docker.registryAuth = {
    enable = true;
    sopsFile = ../../../secrets/users/zebradil.yaml;
    registries.zebradil-oci = {
      endpoints = [
        "oci.zebradil.dev"
        "oci.lan.zebradil.dev"
      ];
      usernameSecret = "docker-oci-username";
      passwordSecret = "docker-oci-password";
    };
  };
}
