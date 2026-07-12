#!/usr/bin/env bash
# Tiberian Sun OpenRA Mod Installer — Linux
# Targets OpenRA playtest-20260222

set -euo pipefail

MOD_VERSION="playtest-20260222"
APPIMAGE_URL="https://github.com/OpenRA/OpenRA/releases/download/${MOD_VERSION}/OpenRA-${MOD_VERSION}.AppImage"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

require_cmd() { command -v "$1" >/dev/null 2>&1 || { error "Required command '$1' not found. Install it and re-run."; exit 1; }; }

# ── Find existing OpenRA installation ────────────────────────────────────────
find_openra() {
    local candidates=(
        "$HOME/.local/share/openra-${MOD_VERSION}/OpenRA"
        "$HOME/.local/share/openra/OpenRA"
        "/opt/openra/OpenRA"
        "/usr/local/bin/OpenRA"
        "/usr/bin/OpenRA"
    )
    for p in "${candidates[@]}"; do
        if [[ -x "$p" ]]; then echo "$p"; return 0; fi
    done
    # Check for AppImage
    local ai_candidates=(
        "$HOME/.local/share/openra-${MOD_VERSION}/OpenRA-${MOD_VERSION}.AppImage"
        "$HOME/Applications/OpenRA-${MOD_VERSION}.AppImage"
        "$HOME/.local/bin/OpenRA-${MOD_VERSION}.AppImage"
    )
    for p in "${ai_candidates[@]}"; do
        if [[ -x "$p" ]]; then echo "$p"; return 0; fi
    done
    return 1
}

# ── Download with progress ────────────────────────────────────────────────────
download_appimage() {
    local dest="$HOME/.local/share/openra-${MOD_VERSION}"
    mkdir -p "$dest"
    local out="${dest}/OpenRA-${MOD_VERSION}.AppImage"

    info "Downloading OpenRA ${MOD_VERSION}..."
    if command -v wget >/dev/null 2>&1; then
        wget --show-progress -qO "$out" "$APPIMAGE_URL"
    elif command -v curl >/dev/null 2>&1; then
        curl -L --progress-bar -o "$out" "$APPIMAGE_URL"
    else
        error "Neither wget nor curl is available. Please install one and re-run."
        exit 1
    fi

    chmod +x "$out"
    echo "$out"
}

# ── Install mod files ─────────────────────────────────────────────────────────
install_mod() {
    local mod_dir="$HOME/.config/openra/mods"
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

# ── Desktop entry ─────────────────────────────────────────────────────────────
create_desktop_entry() {
    local engine_exe="$1"
    local desktop_dir="$HOME/.local/share/applications"
    mkdir -p "$desktop_dir"

    cat > "${desktop_dir}/tiberian-sun-openra.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Tiberian Sun (OpenRA)
Comment=Command & Conquer: Tiberian Sun via OpenRA
Exec=${engine_exe} Game.Mod=ts
Icon=openra-ts
Terminal=false
Categories=Game;StrategyGame;
Keywords=tiberiansun;openra;cnc;
EOF

    # Also place a link on the Desktop if it exists
    if [[ -d "$HOME/Desktop" ]]; then
        cp "${desktop_dir}/tiberian-sun-openra.desktop" "$HOME/Desktop/tiberian-sun-openra.desktop"
        chmod +x "$HOME/Desktop/tiberian-sun-openra.desktop"
        info "Desktop shortcut created at ~/Desktop/tiberian-sun-openra.desktop"
    fi

    info "Application entry created at ${desktop_dir}/tiberian-sun-openra.desktop"
}

# ────────────────────────────────────────────────────────────────────────────
#  MAIN
# ────────────────────────────────────────────────────────────────────────────

echo ""
echo "=============================================="
echo "  Tiberian Sun OpenRA Mod Installer (Linux)"
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
        engine_exe=$(download_appimage)
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

# Step 3: Desktop entry
create_desktop_entry "$engine_exe"

echo ""
info "Tiberian Sun installation complete!"
info "Launch with: ${engine_exe} Game.Mod=ts"
info "The first launch will prompt you to download the free game content files."
echo ""
