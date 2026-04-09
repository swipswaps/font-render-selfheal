# Font Rendering Self-Healing Toolkit

## Overview

Fixes GTK font rendering issues such as:

- □ square glyphs
- missing UI text
- broken fonts in apps like GParted

---

## Root Cause

Font rendering depends on:

- fontconfig
- freetype
- cairo
- pango
- GTK
- X11 DPI settings
- session state

Most failures are caused by stale session state.

---

## Usage

chmod +x font_render_selfheal.sh
./font_render_selfheal.sh

---

## Important

After running:

LOG OUT AND LOG BACK IN

This step is required.

---

## What it fixes

- font cache corruption
- GTK misconfiguration
- missing fallback fonts
- X11 DPI issues

---

## Safe

- Idempotent (can run multiple times)
- Non-destructive
