_: {
  # NixOS-specific overrides for zebradil
  znix = {
    useWritableLinks = false;
    desktop.hyprland.shellPreset = "hyprpanel";
    user = {
      name = "German Lashevich";
      email = "german.lashevich@gmail.com";
    };
  };
  sshPublicKey = builtins.readFile ./ssh.pub;
  znix.docker.multiarchBuilder.enable = true;
}
