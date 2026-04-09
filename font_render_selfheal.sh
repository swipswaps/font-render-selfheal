#!/usr/bin/env bash
set -euo pipefail

LOG="/tmp/font_selfheal_$(date +%s).log"
exec > >(tee -a "$LOG") 2>&1

echo "=== FONT RENDER SELF-HEAL START ==="
echo "Log: $LOG"
echo ""

if [[ $EUID -ne 0 ]]; then
    SUDO="sudo"
else
    SUDO=""
fi

echo "[1] Installing required packages..."
$SUDO dnf install -y \
    fontconfig freetype cairo pango \
    google-noto-sans-fonts google-noto-serif-fonts \
    dejavu-sans-fonts \
    abattis-cantarell-fonts abattis-cantarell-vf-fonts \
    adwaita-fonts || true

echo "[2] Resetting font caches..."
$SUDO rm -rf /var/cache/fontconfig/*
rm -rf ~/.cache/fontconfig || true
fc-cache -rv

echo "[3] Validating fontconfig..."
fc-match "sans" || { echo "fontconfig failure"; exit 1; }

echo "[4] Resetting GTK fonts..."
gsettings set org.gnome.desktop.interface font-name 'Cantarell 11' || true
gsettings set org.gnome.desktop.interface document-font-name 'Cantarell 11' || true
gsettings set org.gnome.desktop.interface monospace-font-name 'DejaVu Sans Mono 11' || true

echo "[5] Normalizing environment..."
export LANG=en_US.UTF-8
unset LC_ALL GDK_SCALE GDK_DPI_SCALE XFT_DPI || true

echo "[6] Reloading X11 resources..."
if command -v xrdb >/dev/null 2>&1; then
    xrdb -merge <<XEOF
Xft.dpi: 96
Xft.antialias: 1
Xft.hinting: 1
XEOF
fi

echo "[7] Creating font fallback override..."
mkdir -p ~/.config/fontconfig

cat > ~/.config/fontconfig/fonts.conf << 'XEOF'
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
XEOF

fc-cache -rv

echo "[8] Rendering test..."
TEST_FILE="/tmp/font_test_$$.txt"
echo "FONT TEST: The quick brown fox jumps over the lazy dog 1234567890" > "$TEST_FILE"

if command -v gedit >/dev/null 2>&1; then
    gedit "$TEST_FILE" >/dev/null 2>&1 &
fi

echo ""
echo "=== RESULT ==="
echo "⚠ IMPORTANT: Log out and log back in for full fix"
echo ""
echo "DONE"
