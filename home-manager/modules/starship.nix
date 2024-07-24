{lib, ...}: {
  programs.starship = {
    enable = true;
    settings = {
      "$schema" = "https://starship.rs/config-schema.json";
      add_newline = true;

      format = lib.concatStrings [
        "$all"
        "$fill"
        "\${custom.docker_host}"
        "$kubernetes"
        "$line_break"
        "$jobs"
        "$battery"
        "$time"
        "$status"
        "$container"
        "$os"
        "$shell"
        "$character"
      ];

      sudo = {
        disabled = false;
      };

      kubernetes = {
        disabled = false;
        # Removed `in` in the end, because it's placed in the end of the line
        format = "[$symbol$context( \\($namespace\\))]($style)";
      };

      gcloud = {
        # Add project name
        format = "on [$symbol$account(@$domain)(\\($project\\))]($style) ";
      };

      openstack = {
        # Removed $cloud, because it's always the same as $project
        format = "on [$symbol$project]($style) ";
      };

      custom.docker_host = {
        symbol = " ";
        command = "docker info --format \"{{.Name}}\"";
        when = "[ ! -z $DOCKER_HOST ]";
        style = "blue bold";
        format = "[$symbol$output]($style)";
      };
    };
  };
}
