# +==========================+
# | TLS                      |
# +--------------------------+

if lib::check_commands curl; then
  log::debug "Configuring TLS functions"

  # Per URL, ask for an ECDSA and an RSA certificate and time cold TLS
  # handshakes for each; N (default 10) sets samples per row.
  # A row whose key differs from the one asked for means the server holds only
  # one certificate; "fail" means it refused that signature algorithm outright
  # (or is unreachable).
  # -k skips certificate verification: loading the CA bundle costs the client
  # ~3.5 ms per connection and would drown the server-side difference.
  function z:tls:keycmp() {
    local n=${N:-10} u want s key
    printf '%-5s %-9s %7s %7s %7s  %s\n' WANT SERVED avg_ms min_ms max_ms URL
    for u in "$@"; do
      for want in ECDSA RSA; do
        case $want in
          ECDSA) s=ecdsa_secp256r1_sha256:ecdsa_secp384r1_sha384 ;;
          RSA) s=rsa_pss_rsae_sha256:rsa_pkcs1_sha256 ;;
        esac
        key=$(curl -skv -o /dev/null --max-time 10 --sigalgs "$s" "$u" 2>&1 |
          sed -n 's/.*level 0: Public key type \([A-Z]*\)[^ ]* (\([0-9]*\).*/\1-\2/p')
        if [[ -z $key ]]; then
          printf '%-5s %-9s %7s %7s %7s  %s\n' "$want" fail - - - "$u"
          continue
        fi
        for _ in $(seq "$n"); do
          curl -sk -o /dev/null --max-time 10 --sigalgs "$s" \
            -w '%{time_connect} %{time_appconnect}\n' "$u"
        done | awk -v u="$u" -v w="$want" -v k="$key" '
          $2 > 0 { h = ($2 - $1) * 1000; t += h; c++
                   if (c == 1 || h < lo) lo = h; if (h > hi) hi = h }
          END { if (c) printf "%-5s %-9s %7.1f %7.1f %7.1f  %s\n", w, k, t/c, lo, hi, u
                else   printf "%-5s %-9s %7s %7s %7s  %s\n", w, k, "-", "-", "-", u }'
      done
    done
  }
  alias tls-keycmp=z:tls:keycmp
fi
