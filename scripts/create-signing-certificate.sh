#!/bin/bash
set -euo pipefail

NAME="Tabby Code Signing"
DIRECTORY="$HOME/.tabby-signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -p codesigning | grep -q "\"$NAME\""; then
    echo "\"$NAME\" already exists in the keychain."
    exit 0
fi

mkdir -p "$DIRECTORY"
chmod 700 "$DIRECTORY"
cat > "$DIRECTORY/openssl.cnf" <<EOF
[ req ]
distinguished_name = dn
x509_extensions = extensions
prompt = no
[ dn ]
CN = $NAME
[ extensions ]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
subjectKeyIdentifier = hash
EOF

PASSWORD="$(/usr/bin/openssl rand -hex 16)"
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$DIRECTORY/openssl.cnf" \
    -keyout "$DIRECTORY/key.pem" -out "$DIRECTORY/certificate.pem" 2>/dev/null
/usr/bin/openssl pkcs12 -export -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 -inkey "$DIRECTORY/key.pem" -in "$DIRECTORY/certificate.pem" \
    -name "$NAME" -out "$DIRECTORY/tabby-signing.p12" -passout "pass:$PASSWORD"
printf '%s' "$PASSWORD" > "$DIRECTORY/p12-password.txt"
rm -f "$DIRECTORY/key.pem"
chmod 600 "$DIRECTORY"/*

security import "$DIRECTORY/tabby-signing.p12" -k "$KEYCHAIN" -P "$PASSWORD" -T /usr/bin/codesign

security find-identity -p codesigning | grep "\"$NAME\""
echo "Backup this folder somewhere safe: $DIRECTORY"
