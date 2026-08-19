SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
OUT_DIR="$REPO_ROOT/out"
MODULE_SYS_DIR="$REPO_ROOT/system/vendor/lib/modules"
MODULE_BIN_DIR="$REPO_ROOT/system/vendor/bin"
mkdir -p "$OUT_DIR" "$MODULE_SYS_DIR" "$MODULE_BIN_DIR"
echo "[+] Building rename_phy binary (aarch64 static)..."
aarch64-linux-gnu-gcc -O2 -static "$SCRIPT_DIR/rename_phy.c" -o "$MODULE_BIN_DIR/rename_phy"
echo "[+] rename_phy built: $MODULE_BIN_DIR/rename_phy"
echo "[+] Building wonder_mosey_wild.ko module..."
if command -v docker >/dev/null 2>&1; then
    docker build -t mosey-kmod -f "$SCRIPT_DIR/Dockerfile.kmod" "$SCRIPT_DIR"
    docker run --rm -v "$SCRIPT_DIR":/src -v "$OUT_DIR":/out mosey-kmod make -C /build M=/src modules
fi
[ -f "$OUT_DIR/wonder_mosey_wild.ko" ] && cp -f "$OUT_DIR/wonder_mosey_wild.ko" "$MODULE_SYS_DIR/wonder_mosey_wild.ko"
echo "[+] Module status: $MODULE_SYS_DIR/wonder_mosey_wild.ko"
