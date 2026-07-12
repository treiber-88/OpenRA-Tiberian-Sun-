#!/usr/bin/env bash
# Tiberian Sun OpenRA Mod Installer — macOS
# Targets OpenRA playtest-20260222

set -euo pipefail

MOD_VERSION="playtest-20260222"
DMG_URL="https://github.com/OpenRA/OpenRA/releases/download/${MOD_VERSION}/OpenRA-${MOD_VERSION}-macOS.zip"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/Applications"
APP_BUNDLE="$INSTALL_DIR/OpenRA.app"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ── Find existing OpenRA ──────────────────────────────────────────────────────
find_openra() {
    local candidates=(
        "/Applications/OpenRA.app/Contents/MacOS/OpenRA"
        "$HOME/Applications/OpenRA.app/Contents/MacOS/OpenRA"
    )
    for p in "${candidates[@]}"; do
        if [[ -x "$p" ]]; then echo "$p"; return 0; fi
    done
    return 1
}

# ── Download and install OpenRA ───────────────────────────────────────────────
install_openra() {
    local tmp_zip="/tmp/OpenRA-${MOD_VERSION}-macOS.zip"
    local tmp_dir="/tmp/OpenRA-${MOD_VERSION}-macOS"

    info "Downloading OpenRA ${MOD_VERSION} for macOS..."
    if command -v curl >/dev/null 2>&1; then
        curl -L --progress-bar -o "$tmp_zip" "$DMG_URL"
    elif command -v wget >/dev/null 2>&1; then
        wget --show-progress -qO "$tmp_zip" "$DMG_URL"
    else
        error "curl or wget is required. Install Homebrew (https://brew.sh) and run: brew install curl"
        exit 1
    fi

    info "Extracting OpenRA..."
    mkdir -p "$tmp_dir"
    unzip -q "$tmp_zip" -d "$tmp_dir"

    # Find the .app bundle inside the extracted folder
    local app_src
    app_src=$(find "$tmp_dir" -name "OpenRA*.app" -maxdepth 2 | head -1)
    if [[ -z "$app_src" ]]; then
        # Some releases extract directly
        app_src="$tmp_dir/OpenRA.app"
    fi

    mkdir -p "$INSTALL_DIR"
    info "Installing OpenRA.app to ${INSTALL_DIR}..."
    cp -rf "$app_src" "$INSTALL_DIR/"

    # Quarantine fix for unsigned app from internet
    xattr -dr com.apple.quarantine "$APP_BUNDLE" 2>/dev/null || true

    rm -rf "$tmp_zip" "$tmp_dir"

    echo "${APP_BUNDLE}/Contents/MacOS/OpenRA"
}

# ── Install mod files ─────────────────────────────────────────────────────────
install_mod() {
    local mod_dir="$HOME/Library/Application Support/OpenRA/mods"
    mkdir -p "$mod_dir"

    local oramod="${SCRIPT_DIR}/ts.oramod"
    if [[ -f "$oramod" ]]; then
        info "Installing ts.oramod..."
        cp -f "$oramod" "${mod_dir}/ts.oramod"
    elif [[ -d "${SCRIPT_DIR}/mods/ts" ]]; then
        info "Installing mods/ts/ directory..."
        mkdir -p "${mod_dir}/ts"
        cp -rf "${SCRIPT_DIR}/mods/ts/." "${mod_dir}/ts/"
    else
        error "Mod files not found in installer directory."
        exit 1
    fi
    info "Mod installed to ${mod_dir}"
}

# ── Dock/Launchpad alias ──────────────────────────────────────────────────────
create_app_alias() {
    local engine_exe="$1"
    # Create a tiny shell-based .app wrapper for Tiberian Sun so it appears in Launchpad
    local ts_app="$INSTALL_DIR/Tiberian Sun.app"
    local mac_dir="${ts_app}/Contents/MacOS"
    local res_dir="${ts_app}/Contents/Resources"
    mkdir -p "$mac_dir" "$res_dir"

    cat > "${mac_dir}/TiberianSun" <<APPEOF
#!/usr/bin/env bash
exec "$(dirname "$engine_exe")/OpenRA" Game.Mod=ts "\$@"
APPEOF
    chmod +x "${mac_dir}/TiberianSun"

    cat > "${ts_app}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>TiberianSun</string>
    <key>CFBundleIdentifier</key><string>net.openra.tiberiansun</string>
    <key>CFBundleName</key><string>Tiberian Sun</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
</dict>
</plist>
PLIST

    xattr -dr com.apple.quarantine "$ts_app" 2>/dev/null || true
    info "Created app bundle: ${ts_app}"
}

# ────────────────────────────────────────────────────────────────────────────
#  MAIN
# ────────────────────────────────────────────────────────────────────────────

echo ""
echo "=============================================="
echo "  Tiberian Sun OpenRA Mod Installer (macOS)"
echo "  Engine target: OpenRA ${MOD_VERSION}"
echo "=============================================="
echo ""

# Step 1: Find or install OpenRA
engine_exe=""
if engine_exe=$(find_openra); then
    info "Found OpenRA at: ${engine_exe}"
else
    warn "OpenRA ${MOD_VERSION} was not found on this system."
    read -rp "Download and install OpenRA ${MOD_VERSION} now? [Y/n] " answer
    answer="${answer:-Y}"
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        engine_exe=$(install_openra)
        info "OpenRA installed at: ${engine_exe}"
    else
        warn "Skipping engine download."
        warn "Please install OpenRA ${MOD_VERSION} from:"
        warn "  https://github.com/OpenRA/OpenRA/releases/tag/${MOD_VERSION}"
        warn "Then run this installer again."
        exit 0
    fi
fi

# Step 2: Install mod files
install_mod

# Step 3: Create app wrapper
create_app_alias "$engine_exe"

echo ""
info "Tiberian Sun installation complete!"
info "Launch from ~/Applications/Tiberian Sun.app or run:"
info "  ${engine_exe} Game.Mod=ts"
info ""
info "The first launch will prompt you to download the free game content files."
echo ""
