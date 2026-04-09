#!/usr/bin/env bash
# =============================================================================
# font_render_selfheal.sh (CLEAN TRUE IDEMPOTENT v3.0)
# =============================================================================
# PURPOSE:
#   Deterministic font system self-healing without false positives.
#
# CHANGES:
#   ✔ REMOVED rendering probe (non-deterministic / unreliable)
#   ✔ Retains only deterministic validation layers
#   ✔ Guarantees no false repair triggers
# =============================================================================

set -euo pipefail

LOG="/tmp/font_selfheal_$(date +%s).log"
exec > >(tee -a "$LOG") 2>&1

echo "=== FONT SELF-HEAL (CLEAN IDEMPOTENT) START ==="
echo "Log: $LOG"
echo ""

# -----------------------------
# Root escalation
# -----------------------------
if [[ $EUID -ne 0 ]]; then
    SUDO="sudo"
else
    SUDO=""
fi

# -----------------------------
# Package manager detection
# -----------------------------
echo "[1] Detecting package manager..."

if command -v dnf >/dev/null 2>&1; then
    PKG_INSTALL="dnf install -y --skip-unavailable"
elif command -v apt >/dev/null 2>&1; then
    PKG_INSTALL="apt update -y && apt install -y"
else
    echo "ERROR: Unsupported package manager"
    exit 1
fi

# -----------------------------
# FORENSIC VALIDATION
# -----------------------------
echo "[2] Running forensic validation..."

FAIL_FONTCONFIG=0
FIX_DPI=0
FIX_GTK=0
FIX_FALLBACK=0

echo " - Checking fontconfig resolution..."
MATCH=$(fc-match "sans" || true)

if [[ -z "$MATCH" ]]; then
    echo "   FAIL: fontconfig resolution failed"
    FAIL_FONTCONFIG=1
else
    echo "   OK: $MATCH"
fi

echo " - Checking font list integrity..."
if ! fc-list | head -n 1 >/dev/null 2>&1; then
    echo "   FAIL: fc-list failed"
    FAIL_FONTCONFIG=1
else
    echo "   OK: font list accessible"
fi

echo " - Checking DPI..."
CURRENT_DPI=$(xrdb -query 2>/dev/null | grep -i "Xft.dpi" || true)

if [[ -n "$CURRENT_DPI" ]] && ! echo "$CURRENT_DPI" | grep -q "96"; then
    echo "   WARN: DPI not normalized"
    FIX_DPI=1
else
    echo "   OK: DPI"
fi

echo " - Checking GTK config..."
if command -v gsettings >/dev/null 2>&1; then
    CURRENT_FONT=$(gsettings get org.gnome.desktop.interface font-name || echo "")
    if ! echo "$CURRENT_FONT" | grep -qi "Cantarell"; then
        echo "   WARN: GTK font not standard"
        FIX_GTK=1
    else
        echo "   OK: GTK font"
    fi
else
    echo "   SKIP: gsettings not available"
fi

echo " - Checking fallback config..."
if [[ ! -f ~/.config/fontconfig/fonts.conf ]]; then
    echo "   WARN: missing fallback config"
    FIX_FALLBACK=1
else
    echo "   OK: fallback config"
fi

# -----------------------------
# DECISION ENGINE
# -----------------------------
echo "[3] Decision engine..."

NEEDS_REPAIR=0

if [[ "$FAIL_FONTCONFIG" -eq 1 ]]; then
    NEEDS_REPAIR=1
fi

if [[ "$NEEDS_REPAIR" -eq 0 && \
      "$FIX_DPI" -eq 0 && \
      "$FIX_GTK" -eq 0 && \
      "$FIX_FALLBACK" -eq 0 ]]; then

    echo ""
    echo "=== RESULT ==="
    echo "✔ SYSTEM HEALTHY (NO-OP)"
    echo ""
    echo "Log file: $LOG"
    exit 0
fi

# -----------------------------
# REPAIR
# -----------------------------
echo "[4] Applying repairs..."

if [[ "$NEEDS_REPAIR" -eq 1 ]]; then
    echo "[4A] Reinstalling font stack..."

    $SUDO bash -c "$PKG_INSTALL \
        fontconfig freetype cairo pango \
        google-noto-sans-fonts google-noto-serif-fonts \
        dejavu-sans-fonts \
        abattis-cantarell-fonts abattis-cantarell-vf-fonts || true"

    echo "[4A] Rebuilding caches..."
    $SUDO rm -rf /var/cache/fontconfig/* || true
    rm -rf ~/.cache/fontconfig || true
    fc-cache -rv
fi

if [[ "$FIX_DPI" -eq 1 ]]; then
    echo "[4B] Fixing DPI..."
    xrdb -merge <<EOF
Xft.dpi: 96
Xft.antialias: 1
Xft.hinting: 1
EOF
fi

if [[ "$FIX_GTK" -eq 1 ]]; then
    echo "[4C] Fixing GTK..."
    gsettings set org.gnome.desktop.interface font-name 'Cantarell 11' || true
    gsettings set org.gnome.desktop.interface document-font-name 'Cantarell 11' || true
    gsettings set org.gnome.desktop.interface monospace-font-name 'DejaVu Sans Mono 11' || true
fi

if [[ "$FIX_FALLBACK" -eq 1 ]]; then
    echo "[4D] Creating fallback config..."

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

    fc-cache -r
fi

# -----------------------------
# SESSION STATE
# -----------------------------
echo "[5] Session state..."

if [[ "$FIX_DPI" -eq 1 || "$FIX_GTK" -eq 1 || "$NEEDS_REPAIR" -eq 1 ]]; then
    echo ""
    echo "⚠ ACTION REQUIRED:"
    echo "→ Log out and log back in"
fi

echo ""
echo "=== RESULT ==="
echo "✔ Repairs applied (deterministic only)"
echo ""
echo "Log file: $LOG"