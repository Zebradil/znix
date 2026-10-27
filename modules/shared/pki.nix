_:
let
  pki = {
    # Eight eMudhra intermediates chaining to this root via Sectigo
    # cross-signs have recoverable private keys. Browsers are covered
    # by CT enforcement; non-browser clients that skip CT and revocation are
    # not. Drop once nixpkgs' cacert distrusts the intermediates.
    # https://emudhra.we-have-a-problem.com/
    security.pki.caCertificateBlacklist = [
      "Comodo AAA Services root"
    ];
  };
in
{
  flake.modules.nixos.pki = pki;
  flake.modules.darwin.pki = pki;
}
