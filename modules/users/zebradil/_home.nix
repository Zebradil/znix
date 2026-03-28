_: {
  # NixOS-specific overrides for zebradil
  znix.useWritableLinks = false;
  znix.user = {
    name = "German Lashevich";
    email = "german.lashevich@gmail.com";
  };
  sshPublicKey = builtins.readFile ./ssh.pub;
}
