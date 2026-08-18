#!/usr/bin/env bash
# build.sh - Build wonder_mosey_wild.ko and rename_phy for Pixel 8a / Pixel 8 series

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
MODULE_SYS_DIR="$REPO_ROOT/system/vendor/lib/modules"
mkdir -p "$OUT_DIR" "$MODULE_SYS_DIR"

echo "[+] Building wonder_mosey_wild.ko module..."
echo "[+] Output path: $OUT_DIR/wonder_mosey_wild.ko"
[ -f "$OUT_DIR/wonder_mosey_wild.ko" ] && cp -f "$OUT_DIR/wonder_mosey_wild.ko" "$MODULE_SYS_DIR/wonder_mosey_wild.ko"
echo "[+] Module copied to: $MODULE_SYS_DIR/wonder_mosey_wild.ko"

