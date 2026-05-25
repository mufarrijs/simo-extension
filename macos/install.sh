#!/usr/bin/env bash
# SimoClip installer — run from the repo root:  bash macos/install.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HS_DIR="$HOME/.hammerspoon"
DATA_DIR="$HOME/.simoclip"

echo ""
echo "  SimoClip installer"
echo "  ──────────────────"
echo ""

# ── 1. Check Hammerspoon ──────────────────────────────────────────────────────

if ! open -Ra Hammerspoon 2>/dev/null; then
    echo "  Hammerspoon not found."
    echo ""
    echo "  Install it first:"
    echo "    brew install --cask hammerspoon"
    echo "  or download from https://hammerspoon.org"
    echo ""
    exit 1
fi
echo "  ✓  Hammerspoon found"

# ── 2. Create ~/.hammerspoon ──────────────────────────────────────────────────

mkdir -p "$HS_DIR"

# ── 3. Back up existing init.lua ──────────────────────────────────────────────

if [[ -f "$HS_DIR/init.lua" ]]; then
    BACKUP="$HS_DIR/init.lua.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$HS_DIR/init.lua" "$BACKUP"
    echo "  ✓  Existing init.lua backed up → $BACKUP"
fi

# ── 4. Copy config ────────────────────────────────────────────────────────────

cp "$SCRIPT_DIR/hammerspoon/init.lua" "$HS_DIR/init.lua"
echo "  ✓  Config installed → $HS_DIR/init.lua"

# ── 5. Create data dir ────────────────────────────────────────────────────────

mkdir -p "$DATA_DIR"
chmod 700 "$DATA_DIR"
echo "  ✓  Data directory → $DATA_DIR"

# ── 6. Reload Hammerspoon ─────────────────────────────────────────────────────

if pgrep -x Hammerspoon > /dev/null 2>&1; then
    osascript -e 'tell application "Hammerspoon" to reload()'
    echo "  ✓  Hammerspoon reloaded"
else
    open -a Hammerspoon
    echo "  ✓  Hammerspoon launched"
fi

echo ""
echo "  Done!  You should see 'SimoClip ready' appear on screen."
echo ""
echo "  Next steps:"
echo "   • If prompted, grant Accessibility permission in"
echo "     System Settings → Privacy & Security → Accessibility"
echo "   • Press Cmd+Shift+0 to open the slot panel"
echo ""
echo "  Optional AI search:"
echo "   echo 'sk-ant-YOUR_KEY' > ~/.simoclip/claude_api_key"
echo "   then press Cmd+Shift+A"
echo ""
