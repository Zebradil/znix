_: {
  flake.modules.homeManager.user-identity =
    { lib, ... }:
    {
      options = {
        znix.user = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "User's full name (used in git, etc.)";
          };
          email = lib.mkOption {
            type = lib.types.str;
            description = "User's email address (used in git, etc.)";
          };
        };

        sshPublicKey = lib.mkOption {
          type = lib.types.str;
          description = "SSH public key used for git commit signing via 1Password";
        };
      };
    };
}
