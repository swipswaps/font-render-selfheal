# Font Rendering Self-Healing Toolkit

## Overview

This toolkit automatically detects and repairs common Linux font rendering issues, including:

- □ square glyph glyphs in UI
- missing or broken text rendering in GTK apps
- GParted menu rendering issues
- fontconfig / cache inconsistencies
- X11 DPI misconfiguration
- stale session font state

---

## Root Cause (What Actually Breaks)

Font rendering depends on multiple layers:

- fontconfig (font discovery & matching)
- freetype (font rasterization)
- cairo (drawing engine)
- pango (layout engine)
- GTK (UI font selection)
- X11 / XRDB (DPI scaling)
- user session state (critical)

Most failures occur due to:

- stale font caches
- inconsistent GTK settings
- incorrect or non-standard DPI
- incomplete session reload

---

## How It Works

The script performs **deterministic forensic checks only**:

- `fc-match` → validates font resolution
- `fc-list` → validates font database accessibility
- DPI query via `xrdb`
- GTK font settings via `gsettings`
- fallback config verification

If and only if failures are detected:

- font packages are ensured installed
- font caches are rebuilt
- DPI is normalized
- GTK defaults are restored
- fallback fontconfig rules are written

---

## Idempotency Guarantee

✔ The script is **safe to run multiple times**  
✔ It performs **no changes unless a failure is detected**  
✔ It avoids false positives by design  

---

## Usage

```bash
chmod +x font_render_selfheal.sh
./font_render_selfheal.sh
Important Requirement

After running the script:

👉 Log out and log back in

This is required because:

GTK and X11 settings are session-scoped
DPI and font settings do not fully apply until session reload
Validation Output

A healthy system will show:

✔ SYSTEM HEALTHY (NO-OP)

or:

✔ Repairs applied (deterministic only)
Safety
Non-destructive
Idempotent
No forced overrides without detection
No GUI dependencies
No rendering hangs
No blocking probes
Supported Systems
Fedora (tested)
RHEL-based systems
Debian/Ubuntu (with apt fallback)
Repository Structure
font-render-selfheal/
├── font_render_selfheal.sh
└── README.md
License

MIT (or your preferred license)
