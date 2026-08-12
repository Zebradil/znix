# Plain function, not a flake-parts module — import it for the derivation, do
# not add it to a module `imports` list.
{ pkgs }:
pkgs.writeShellApplication {
  name = "anyrun-pick";
  runtimeInputs = [ pkgs.anyrun ];
  text = ''
    # Reads newline-separated options on stdin, prints the chosen one.
    #
    # anyrun's stdin plugin emits the entry title with no trailing newline, and
    # in standalone mode anyrun writes it twice: once eagerly on selection and
    # once more from the close handler. Rather than trusting the raw bytes, map
    # them back onto an option we actually offered.
    options=$(cat)
    [[ -n $options ]] || exit 0

    stdin_lib="$(dirname "$(command -v anyrun)")/../lib/libstdin.so"
    chosen=$(printf '%s\n' "$options" | anyrun --plugins "$stdin_lib" --show-results-immediately true)
    [[ -n $chosen ]] || exit 0

    while IFS= read -r option; do
      if [[ $chosen == "$option" || $chosen == "$option$option" ]]; then
        printf '%s\n' "$option"
        exit 0
      fi
    done <<<"$options"

    printf '%s\n' "$chosen"
  '';
}
