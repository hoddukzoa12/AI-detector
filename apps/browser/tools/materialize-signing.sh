#!/usr/bin/env bash
set -euo pipefail

# Materialize the Android release signing config from principal-secrets-mono
# (SOPS + age, the secret source of truth; Infisical is retired).
# Reads 4 fields and writes android/key.properties + the keystore file.
# Both outputs are gitignored. Run before `flutter build appbundle --release`.
#
# Environment:
#   PRINCIPAL_SECRETS_ROOT  path to a principal-secrets-mono checkout (required)
#   SOPS_AGE_KEY_FILE       age identity file (default: ~/.config/sops/age/macbook-se.txt)
#
# Fields of secrets/android-signing/infocutter-upload.enc.yaml:
#   keystore_jks_b64  base64 of the upload keystore (.jks)
#   store_password    store password
#   key_password      key password
#   key_alias         key alias

fail() { echo "materialize-signing: $*" >&2; exit 1; }

SECRETS_ROOT="${PRINCIPAL_SECRETS_ROOT:?set PRINCIPAL_SECRETS_ROOT to a principal-secrets-mono checkout (e.g. .../principal-secrets-mono/main)}"
SECRET_FILE="$SECRETS_ROOT/secrets/android-signing/infocutter-upload.enc.yaml"
export SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/macbook-se.txt}"

command -v sops >/dev/null 2>&1 || fail "sops not found on PATH (brew install sops age-plugin-se)"
[ -f "$SOPS_AGE_KEY_FILE" ] || fail "age identity file not found: $SOPS_AGE_KEY_FILE (set SOPS_AGE_KEY_FILE)"
[ -f "$SECRET_FILE" ] || fail "signing secret not found: $SECRET_FILE (check PRINCIPAL_SECRETS_ROOT and pull principal-secrets-mono)"

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_DIR="$APP_DIR/android"
KEYSTORE_FILE="infocutter-upload.jks"
KEYSTORE_PATH="$ANDROID_DIR/app/$KEYSTORE_FILE"

get() {
  sops --decrypt --extract "[\"$1\"]" "$SECRET_FILE" || fail "cannot decrypt field $1 from $SECRET_FILE"
}

# Decrypt everything before writing so a failure leaves no half-written config.
KEYSTORE_B64="$(get keystore_jks_b64)"
STORE_PASSWORD="$(get store_password)"
KEY_PASSWORD="$(get key_password)"
KEY_ALIAS="$(get key_alias)"

printf '%s' "$KEYSTORE_B64" | base64 --decode > "$KEYSTORE_PATH"

umask 077
{
  echo "storeFile=$KEYSTORE_FILE"
  echo "storePassword=$STORE_PASSWORD"
  echo "keyPassword=$KEY_PASSWORD"
  echo "keyAlias=$KEY_ALIAS"
} > "$ANDROID_DIR/key.properties"

echo "signing materialized -> $KEYSTORE_PATH + $ANDROID_DIR/key.properties"
