_:
let
  pki = {
    security.pki.caCertificateBlacklist = [
      "Comodo AAA Services root"
      "emSign ECC Root CA - G3"
    ];
  };
in
{
  flake.modules.nixos.pki = pki;
  flake.modules.darwin.pki = pki;
}
