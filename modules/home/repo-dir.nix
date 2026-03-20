{ self, ... }:
{
  flake.modules.homeManager.repo-dir =
    { config, lib, ... }:
    {
      options.znix = {
        repoDir = lib.mkOption {
          type = lib.types.str;
          default = "${config.home.homeDirectory}/code/github.com/zebradil/znix";
          description = "Absolute path to the znix repository checkout";
        };
        useWritableLinks = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Use writable out-of-store symlinks for editable config files";
        };
        mkRepoLink = lib.mkOption {
          type = lib.types.functionTo lib.types.path;
          readOnly = true;
          default =
            relPath:
            if config.znix.useWritableLinks then
              config.lib.file.mkOutOfStoreSymlink "${config.znix.repoDir}/${relPath}"
            else
              "${self}/${relPath}";
          description = "Create a link to a repo path — writable symlink or store path depending on useWritableLinks";
        };
      };
    };
}
