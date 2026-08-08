#!/usr/bin/env bash
# Generate a self-signed certificate for the local stack.
#
# Let's Encrypt cannot issue for *.localhost — it is not a public name and there
# is no way to prove control of it. So development TLS is a self-signed cert,
# served as Traefik's default certificate (see infrastructure/traefik/dynamic/tls.yml).
# Production swaps the *source* of the certificate to ACME; the routing is identical.
#
# The certificate and key are gitignored: a private key never belongs in a repo.
# Re-run this script on any machine that checks the repo out.

set -euo pipefail

CERT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/infrastructure/traefik/certs"
mkdir -p "$CERT_DIR"

# 825 days is the maximum lifetime browsers accept for a leaf certificate.
openssl req -x509 -nodes -newkey rsa:2048 \
  -keyout "$CERT_DIR/local-key.pem" \
  -out "$CERT_DIR/local-cert.pem" \
  -days 825 \
  -subj "/CN=*.localhost" \
  -addext "subjectAltName=DNS:localhost,DNS:*.localhost" \
  -addext "basicConstraints=critical,CA:FALSE" \
  -addext "keyUsage=critical,digitalSignature,keyEncipherment" \
  -addext "extendedKeyUsage=serverAuth" \
  2>/dev/null

chmod 600 "$CERT_DIR/local-key.pem"
chmod 644 "$CERT_DIR/local-cert.pem"

echo "wrote $CERT_DIR/local-cert.pem (+ key), valid 825 days"
echo "browsers will warn on this certificate — it is self-signed, that is expected."
