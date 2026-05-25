# :) SimoClip

**HELLO, this gives you 10 persistent clipboard slots + works in every app, on Mac and Windows LET'S GO.**

Copy something to a named slot, paste it back days or weeks later. Regular copy-paste is never touched.

---

## IMPORTANT: How it works

| Action | Mac | Windows |
|--------|-----|---------|
| Save to slot 3 | `Cmd+C` → hold Cmd → press `3` | `Ctrl+C` → hold Ctrl → press `3` |
| Paste from slot 3 | `Cmd+B` → hold Cmd → press `3` | `Ctrl+B` → hold Ctrl → press `3` |
| Open panel | Click `:)` in menu bar | `Ctrl+Shift+0` |
| History | `Cmd+Shift+H` | `Ctrl+Shift+H` |
| AI search | `Cmd+Shift+A` | — |
| Enable/disable | `Cmd+Shift+E` | `Ctrl+Shift+E` |
| Clear all slots | `Cmd+Shift+X` | `Ctrl+Shift+X` |

> **Cmd+C and Cmd+V (or Ctrl+C / Ctrl+V) are never intercepted.** The chord only fires when you press a digit within ~1 second of the copy/paste key, while still holding the modifier.

---

## Install — Mac

### 1. Install Hammerspoon (free, open source)
```bash
brew install --cask hammerspoon
# or download from https://hammerspoon.org
```

### 2. Run the installer
```bash
git clone https://github.com/mufarrijs/simo-extension
cd simo-extension
bash macos/install.sh
```

### 3. Grant Accessibility permission
Open **System Settings → Privacy & Security → Accessibility** → enable Hammerspoon.

You'll see **":) SimoClip ready"** flash on screen and a `:)` icon appear in your menu bar.

---

## Install — Windows

### 1. Install AutoHotkey v2
Download from **https://www.autohotkey.com** (free, open source).

### 2. Run the script
Double-click `windows/simoclip.ahk`.

A `:)` icon appears in your system tray. Done.

### 3. Run on startup (optional)
Press `Win+R`, type `shell:startup`, press Enter.  
Copy a shortcut to `simoclip.ahk` into that folder.

---

## All shortcuts

### Mac

| Shortcut | Action |
|----------|--------|
| `Cmd+C` → `Cmd+0–9` | Save to slot |
| `Cmd+B` → `Cmd+0–9` | Paste from slot |
| Click `:)` in menu bar | Open Slots / History panel |
| `Cmd+Shift+H` | Search history (keyboard) |
| `Cmd+Shift+U` | URL history only |
| `Cmd+Shift+A` | AI smart search |
| `Cmd+Shift+E` | Toggle on / off |
| `Cmd+Shift+X` | Clear all slots |
| `Cmd+Ctrl+Shift+Delete` | Clear history |

### Windows

| Shortcut | Action |
|----------|--------|
| `Ctrl+C` → `Ctrl+0–9` | Save to slot |
| `Ctrl+B` → `Ctrl+0–9` | Paste from slot |
| `Ctrl+Shift+0` | Open slot viewer |
| `Ctrl+Shift+H` | History viewer |
| `Ctrl+Shift+E` | Toggle on / off |
| `Ctrl+Shift+X` | Clear all slots |

---

## Features

- **10 slots, C0–C9** — copy text, URLs, images, files
- **Permanent** — slots survive reboots. Come back a week later, everything is still there
- **Full clipboard history** — every copy recorded automatically
- **Searchable history** — keyword search built in; filter by URLs or by slot (type `c3` in the search box)
- **AI smart search** — describe what you're looking for in plain English (optional, Claude API)
- **Enable/disable** toggle
- **No account, no cloud, no telemetry** — 100% local

---

## AI search (optional, Mac)

1. Get a key at **https://console.anthropic.com**
2. Save it:
   ```bash
   echo "sk-ant-YOUR_KEY" > ~/.simoclip/claude_api_key
   ```
3. Press `Cmd+Shift+A` and describe what you want.

Your history is sent to the Claude API only during that search. Nothing else ever leaves your machine.

---

## Is this safe?

**Yes — here's exactly what the script does and doesn't do:**

| Claim | Reality |
|-------|---------|
| Keylogger? | **No.** The script detects only two specific key combinations (`Cmd+C` and `Cmd+B`). It never records what you type. |
| Sends data anywhere? | **No.** Everything is stored locally in `~/.simoclip/`. The only network call is the optional AI search, and only when you explicitly trigger it. |
| Can someone hack you through it? | **No.** The script has no server, no open ports, no auto-update mechanism, and no remote code execution. It reads and writes local files only. |
| Can you verify it? | **Yes.** Both scripts (`init.lua` and `simoclip.ahk`) are plain text you can read in any editor before running. ~600 lines each, fully auditable. |
| What permission does it need? | **Accessibility** on Mac (required by any system-wide shortcut tool: Alfred, Raycast, Karabiner all need the same). On Windows, AutoHotkey runs as a regular user app. |
| Does Hammerspoon phone home? | **No.** Hammerspoon is open source (https://github.com/Hammerspoon/hammerspoon) and has been audited by the community since 2013. |

The worst-case risk of running this is the same as running any script you download: **always read the source before running.** Both scripts are short enough to read in 5 minutes.

---

## Data location

| Mac | Windows |
|-----|---------|
| Slots: `~/.simoclip/slots.json` | `%APPDATA%\SimoClip\slots.ini` |
| History: `~/.simoclip/history.json` | `%APPDATA%\SimoClip\history.txt` |
| API key: `~/.simoclip/claude_api_key` | — |

To wipe everything on Mac: `rm -rf ~/.simoclip/`  
To wipe on Windows: delete `%APPDATA%\SimoClip\`

---

## Update

**Mac:**
```bash
git pull
cp macos/hammerspoon/init.lua ~/.hammerspoon/init.lua
# Hammerspoon menu bar → Reload Config
```

**Windows:**  
Replace `simoclip.ahk` with the new version and re-run it.

---

## Uninstall

**Mac:**
```bash
rm ~/.hammerspoon/init.lua
rm -rf ~/.simoclip/
# Then quit Hammerspoon from the menu bar
```

**Windows:**  
Right-click the tray icon → Exit SimoClip.  
Delete `simoclip.ahk` and `%APPDATA%\SimoClip\`.

---

## License

MIT — use it, fork it, share it.
