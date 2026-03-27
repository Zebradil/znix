_: {
  flake.modules.nixos.openssh =
    {
      lib,
      config,
      ...
    }:
    let
      hasOptinPersistence = config.environment.persistence ? "/persist";
    in
    {
      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          PermitRootLogin = "no";
          StreamLocalBindUnlink = "yes";
          GatewayPorts = "clientspecified";
        };
        hostKeys = [
          {
            path = "${lib.optionalString hasOptinPersistence "/persist"}/etc/ssh/ssh_host_ed25519_key";
            type = "ed25519";
          }
        ];
      };

      security.pam.sshAgentAuth = {
        enable = true;
        authorizedKeysFiles = [ "/etc/ssh/authorized_keys.d/%u" ];
      };
    };
}
