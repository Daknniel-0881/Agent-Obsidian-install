#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OS_NAME="$(uname -s)"

case "$OS_NAME" in
  Darwin)
    exec "$ROOT_DIR/scripts/install-macos.sh" "$@"
    ;;
  Linux)
    exec "$ROOT_DIR/scripts/install-linux.sh" "$@"
    ;;
  *)
    echo "Unsupported OS: $OS_NAME"
    echo "On Windows, run scripts\\bootstrap.ps1 from PowerShell."
    exit 1
    ;;
esac

