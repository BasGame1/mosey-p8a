build_wonder() {
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  OUT_DIR="$REPO_ROOT/out/module"
  MODULE_SYS_DIR="$REPO_ROOT/system/vendor/lib/modules"
  MODULE_BIN_DIR="$REPO_ROOT/system/vendor/bin"
  mkdir -p "$OUT_DIR" "$MODULE_SYS_DIR" "$MODULE_BIN_DIR"

  echo "[+] Building rename_phy binary (aarch64 static)..."
  if command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
      aarch64-linux-gnu-gcc -O2 -static "$SCRIPT_DIR/rename_phy.c" -o "$MODULE_BIN_DIR/rename_phy"
      echo "[+] rename_phy built: $MODULE_BIN_DIR/rename_phy"
  else
      echo "[-] aarch64-linux-gnu-gcc not found, skipping rename_phy cross-compilation"
  fi

  echo "[+] Building wonder_mosey_wild.ko module..."
  KDIR="${KDIR:-/lib/modules/$(uname -r)/build}"
  if [ -d "$KDIR" ]; then
      make -C "$KDIR" M="$SCRIPT_DIR" modules
      [ -f "$SCRIPT_DIR/wonder_mosey_wild.ko" ] && cp -f "$SCRIPT_DIR/wonder_mosey_wild.ko" "$OUT_DIR/wonder_mosey_wild.ko"
  else
      echo "[-] Kernel build headers not found at $KDIR"
  fi

  [ -f "$OUT_DIR/wonder_mosey_wild.ko" ] && cp -f "$OUT_DIR/wonder_mosey_wild.ko" "$MODULE_SYS_DIR/wonder_mosey_wild.ko"
  echo "[+] Module status: $MODULE_SYS_DIR/wonder_mosey_wild.ko"
}
