# SimoClip — Multi-slot clipboard for macOS

System-wide, works in every app (Chrome, Safari, Xcode, Terminal, …).
No account. No cloud. Everything stored locally on your Mac.

---

## What it does

You get **10 named clipboard slots (C0 – C9)** that survive indefinitely —
close your laptop, come back a week later, they're still there.

| Action | Shortcut |
|--------|----------|
| Copy to slot N | `Cmd+C` → then (still holding Cmd) press `N` |
| Paste from slot N | `Cmd+V` → then (still holding Cmd) press `N` |
| Show slot panel | `Cmd+Shift+0` |
| Browse full history | `Cmd+Shift+H` |
| Browse URL history | `Cmd+Shift+U` |
| AI smart search | `Cmd+Shift+A` |
| Enable / disable | `Cmd+Shift+E` |
| Clear all slots | `Cmd+Shift+X` |
| Clear history | `Cmd+Ctrl+Shift+Delete` |

**Regular `Cmd+C` and `Cmd+V` are never blocked.** SimoClip only activates
the chord if you press a digit key within ~1 second of Cmd+C or Cmd+V
*while still holding Cmd*.

---

## Install (5 minutes)

### 1 — Install Hammerspoon

Download from **https://hammerspoon.org** and drag it to Applications.

Or via Homebrew:
```
brew install --cask hammerspoon
```

### 2 — Copy the config

```bash
mkdir -p ~/.hammerspoon
cp macos/hammerspoon/init.lua ~/.hammerspoon/init.lua
```

If you already have an `init.lua`, append with:
```bash
cat macos/hammerspoon/init.lua >> ~/.hammerspoon/init.lua
```

### 3 — Grant Accessibility permission

Open Hammerspoon → it will ask for **Accessibility** access.
Allow it in **System Settings → Privacy & Security → Accessibility**.

This is the only permission the app needs. It lets Hammerspoon see
keyboard events globally (same permission any clipboard manager needs).

### 4 — Reload

In the Hammerspoon menu bar icon → **Reload Config**.

You'll see "SimoClip ready" in the centre of your screen.

---

## AI search (optional)

SimoClip can use Claude to do natural-language search over your history
("find the GitHub link I copied last week", "show me all Python snippets").

1. Get a Claude API key from **https://console.anthropic.com**
2. Save it to a plain-text file:
   ```bash
   echo "sk-ant-..." > ~/.simoclip/claude_api_key
   ```
3. Press `Cmd+Shift+A` and type your query.

Your clipboard history is sent to the Claude API for the search request
and nowhere else. No account required beyond the API key.

---

## Data & privacy

| What | Where |
|------|-------|
| Slots | `~/.simoclip/slots.json` |
| History | `~/.simoclip/history.json` |
| AI key | `~/.simoclip/claude_api_key` |

Everything lives on your Mac. Nothing is sent anywhere unless you use
AI search. To wipe everything: `rm -rf ~/.simoclip/`.

---

## Updating

```bash
cp macos/hammerspoon/init.lua ~/.hammerspoon/init.lua
# then Hammerspoon menu → Reload Config
```

## Uninstall

```bash
rm ~/.hammerspoon/init.lua
rm -rf ~/.simoclip/
```
Then quit Hammerspoon.
