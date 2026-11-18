#!/bin/bash
set -euo pipefail
ENOUGH_IDENTITY_NAME="Enough Development"
ENOUGH_DAYS=7300
ENOUGH_WORK="$(mktemp -d)"
trap 'rm -rf "$ENOUGH_WORK"' EXIT
# Match without -v: a self-signed identity is never "valid" (untrusted root), but codesign can still use it.
if security find-identity -p codesigning | grep -q "\"$ENOUGH_IDENTITY_NAME\""; then
  printf 'Signing identity "%s" already exists.\n' "$ENOUGH_IDENTITY_NAME"
  exit 0
fi
cat > "$ENOUGH_WORK/openssl.cnf" <<'EOF'
[req]
distinguished_name = dn
[dn]
[v3_codesign]
basicConstraints = critical, CA:FALSE
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
subjectKeyIdentifier = hash
EOF
openssl req -new -newkey rsa:2048 -nodes -keyout "$ENOUGH_WORK/key.pem" -out "$ENOUGH_WORK/csr.pem" -subj "/CN=$ENOUGH_IDENTITY_NAME" -config "$ENOUGH_WORK/openssl.cnf"
openssl x509 -req -in "$ENOUGH_WORK/csr.pem" -signkey "$ENOUGH_WORK/key.pem" -days "$ENOUGH_DAYS" -extfile "$ENOUGH_WORK/openssl.cnf" -extensions v3_codesign -out "$ENOUGH_WORK/cert.pem"
# LibreSSL PKCS#12 output is rejected by `security import`; import the key and certificate directly.
security import "$ENOUGH_WORK/key.pem" -k "$HOME/Library/Keychains/login.keychain-db" -T /usr/bin/codesign
security import "$ENOUGH_WORK/cert.pem" -k "$HOME/Library/Keychains/login.keychain-db"
security find-identity -p codesigning
printf 'Created "%s". make install now signs with it, so Accessibility keeps working across rebuilds.\n' "$ENOUGH_IDENTITY_NAME"
