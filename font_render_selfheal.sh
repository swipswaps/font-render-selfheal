#!/usr/bin/env bash
set -euo pipefail

LOG="/tmp/font_selfheal_$(date +%s).log"
exec > >(tee -a "$LOG") 2>&1

echo "=== FONT RENDER SELF-HEAL START ==="
echo "Log: $LOG"
echo ""

# -----------------------------
# 0. Root escalation
# -----------------------------
if [[ $EUID -ne 0 ]]; then
    SUDO="sudo"
else
    SUDO=""
fi

# -----------------------------
# 1. Detect package manager
# -----------------------------
echo "[1] Detecting package manager..."

if command -v dnf >/dev/null 2>&1; then
    PKG_INSTALL="dnf install -y"
elif command -v apt >/dev/null 2>&1; then
    PKG_INSTALL="apt update -y && apt install -y"
else
    echo "ERROR: Unsupported package manager"
    exit 1
fi

# -----------------------------
# 2. Install required packages
# -----------------------------
echo "[2] Installing required packages..."

$SUDO bash -c "$PKG_INSTALL \
    fontconfig \
    freetype \
    cairo \
    pango \
    fonts-noto-core || true"

# Fedora-specific (safe fallback)
$SUDO bash -c "$PKG_INSTALL \
    google-noto-sans-fonts \
    google-noto-serif-fonts \
    dejavu-sans-fonts \
    abattis-cantarell-fonts \
    abattis-cantarell-vf-fonts \
    adwaita-fonts || true"

# -----------------------------
# 3. Reset font caches
# -----------------------------
echo "[3] Resetting font caches..."

$SUDO rm -rf /var/cache/fontconfig/* || true
rm -rf ~/.cache/fontconfig || true

fc-cache -rv

# -----------------------------
# 4. Validate fontconfig
# -----------------------------
echo "[4] Validating fontconfig..."

if ! fc-match "sans" >/dev/null 2>&1; then
    echo "ERROR: fontconfig resolution failed"
    exit 1
fi

# deeper validation
fc-list | grep -qi "noto\|dejavu\|cantarell" || {
    echo "WARNING: expected fonts not detected"
}

# -----------------------------
# 5. Reset GTK fonts (if available)
# -----------------------------
echo "[5] Resetting GTK font configuration..."

if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface font-name 'Cantarell 11' || true
    gsettings set org.gnome.desktop.interface document-font-name 'Cantarell 11' || true
    gsettings set org.gnome.desktop.interface monospace-font-name 'DejaVu Sans Mono 11' || true
else
    echo "Skipping gsettings (not available)"
fi

# -----------------------------
# 6. Normalize environment
# -----------------------------
echo "[6] Normalizing environment..."

export LANG=en_US.UTF-8
unset LC_ALL || true
unset GDK_SCALE || true
unset GDK_DPI_SCALE || true
unset XFT_DPI || true

# -----------------------------
# 7. Reload X11 resources
# -----------------------------
echo "[7] Reloading X11 resources..."

if command -v xrdb >/dev/null 2>&1; then
    xrdb -merge <<EOF
Xft.dpi: 96
Xft.antialias: 1
Xft.hinting: 1
EOF
fi

# -----------------------------
# 8. Font fallback override
# -----------------------------
echo "[8] Creating font fallback override..."

mkdir -p ~/.config/fontconfig

cat > ~/.config/fontconfig/fonts.conf <<'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
 <alias>
  <family>sans-serif</family>
  <prefer>
   <family>Cantarell</family>
   <family>Noto Sans</family>
   <family>DejaVu Sans</family>
  </prefer>
 </alias>
</fontconfig>
EOF

fc-cache -rv

# -----------------------------
# 9. Rendering test
# -----------------------------
echo "[9] Running rendering test..."

TEST_FILE="/tmp/font_test_$$.txt"
echo "FONT TEST: The quick brown fox jumps over the lazy dog 1234567890 □" > "$TEST_FILE"

if command -v gedit >/dev/null 2>&1; then
    gedit "$TEST_FILE" >/dev/null 2>&1 &
fi

# -----------------------------
# 10. Final result
# -----------------------------
echo ""
echo "=== RESULT ==="
echo "⚠ IMPORTANT: Log out and log back in for full fix"
echo ""
echo "Log file: $LOG"
echo "DONE"