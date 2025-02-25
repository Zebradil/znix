# Fix for openssl certificate issues on macOS.
# The following code extracts all certificates from the macOS keychain and adds them to a single file.
# This file is then used by openssl to verify certificates.

[[ $OSTYPE == darwin* ]] || return 0

export SSL_CERT_FILE=${XDG_STATE_HOME:?}/ssl/certs.pem
if [[ -n $SSL_CERT_FILE(#qN.mh-24) ]]; then
  log::debug "SSL_CERT_FILE already exists"
else
  log::info "Updating SSL_CERT_FILE"
  {
    security find-certificate -a -p
    security find-certificate -a -p /System/Library/Keychains/SystemRootCertificates.keychain
  }> $SSL_CERT_FILE
fi
