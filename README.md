# MacRemoteMCP

For the source-only HTTPS and network Settings extension, see [HTTPS and network Settings](docs/https-network-settings.md).

A macOS menu bar app + MCP server for remotely controlling a Mac from Claude.ai / Claude Code.

Start all services with one click and securely control your Mac from anywhere in the world via a Cloudflare Tunnel.

## Features

- **Menu bar app** — Drag-and-drop install from a DMG, full control from the menu bar
- **34 MCP tools** — Shell execution, GUI control, file management, app control
- **Cloudflare Tunnel integration** — Supports fixed URLs, no port forwarding required
- **Settings window** — API key management, port configuration, permission status, Cloudflare setup wizard
- **Apple Developer ID signed + Notarized** — Gatekeeper-compatible

## Architecture

```
Claude.ai ──HTTPS──► Cloudflare Tunnel (Fixed URL or Quick Tunnel)
                      + Bearer auth
                          │
                     Mac (localhost)
                      ├─ MacRemoteMCP.app (resident in menu bar)
                      ├─ MCP server    :3000 (34 tools)
                      ├─ Playwright    :3001 (browser automation)
                      ├─ Auth proxy    :3002 (Bearer auth for Playwright)
                      ├─ caffeinate    (prevents sleep)
                      └─ cloudflared   (Cloudflare Tunnel)
```

## Installation

### Method 1: Install from DMG (recommended)

1. Download the latest `MacRemoteMCP.dmg` from [Releases](https://github.com/DaisukeHori/mac-remote-mcp/releases)
2. Double-click the DMG → drag `MacRemoteMCP.app` into `Applications`
3. Launch `MacRemoteMCP.app`

### Method 2: Build from source

```bash
git clone https://github.com/DaisukeHori/mac-remote-mcp.git
cd mac-remote-mcp
npm install && npm run build
cd app && chmod +x build.sh && ./build.sh
```

### Requirements

- macOS 13.0 or later
- Node.js 20 or later (`brew install node`)
- tmux (`brew install tmux`)
- cloudflared (`brew install cloudflared`) — only needed when using Tunnel

## First-time setup

### 1. Grant permissions

A dialog appears the first time the app launches. Grant the following permissions:

| Permission | Purpose | Auto-configurable |
|---|---|---|
| **Accessibility** | Mouse/keyboard control, reading UI elements | Yes, via PPPC configuration profile |
| **Screen Recording** | Taking screenshots | ❌ Manual only (Apple restriction) |
| **Automation** | App control (System Events) | Yes, via PPPC configuration profile |
| **Full Disk Access** | Reading/writing files (optional) | Yes, via PPPC configuration profile |

> **Note:** After changing permissions, you **must restart the app** (macOS caches permissions per-process, and the cache isn't refreshed otherwise).

### 2. Register with Claude.ai

1. Click the MacRemoteMCP icon in the menu bar
2. Click "Start All"
3. Click "Copy MCP URL"
4. Claude.ai → Settings → Connectors → Add Custom Connector
5. Paste the copied URL into the URL field
6. Auth: Bearer → copy the API key from the menu and paste it in

## Menu layout

```
● Running — Published Online
API Key: xxxx... (click to copy)
────────────────────
▶ Start MCP Server
▶ Start Playwright
▶ Start Sleep Prevention
────────────────────
🌐 Tunnel: https://mac-remote.example.com
▶ Start Fixed Tunnel / Start Quick Tunnel (Free)
Copy MCP URL
────────────────────
Start All
Stop All
────────────────────
Open Logs...
Edit Settings...
Set Up Permissions...
Install Configuration Profile...
────────────────────
Quit MacRemoteMCP
```

## Settings window

The settings window, opened from "Edit Settings...", manages the following:

- **API Key** — view, copy, and regenerate (rotate)
- **Port Settings** — MCP server / Playwright / Auth proxy
- **Auto Start** — automatically start all services on app launch
- **Cloudflare Tunnel** — enter a tunnel token, or run the setup wizard
- **Permission Status** — ✅/❌ display for Accessibility / Screen Recording, with links to the relevant settings screens

> Clicking Save writes to `.env` and then automatically restarts the app.

## Setting up a fixed Cloudflare Tunnel URL

### Method 1: In-app wizard (recommended)

1. Open the Settings window
2. Click "Set Up Fixed URL..."
3. Follow the wizard's instructions:
   - Create a Cloudflare API token (a browser opens automatically)
   - Select a domain
   - Enter a subdomain (e.g. `mac-remote`)
4. The wizard automatically creates the tunnel → configures DNS → saves the token → restarts the app

### Method 2: Manual setup

```bash
# Create the tunnel
cloudflared tunnel create mac-remote-mcp
cloudflared tunnel route dns mac-remote-mcp mac-remote.yourdomain.com

# Get the token
cloudflared tunnel token mac-remote-mcp

# Paste the token into the "Tunnel Token" field in the Settings window → Save
```

### Method 3: Quick Tunnel (free, random URL)

Leaving the Tunnel Token field blank generates a new random URL automatically each time. Ideal for testing.

## Tool list (34 tools)

| Category | Tool | Description |
|---|---|---|
| **Shell** | `shell_execute` | Persistent shell execution via tmux session |
| | `shell_execute_simple` | One-shot command execution |
| | `shell_list_sessions` | List active sessions |
| | `shell_kill_session` | Terminate a session |
| **GUI** | `gui_screenshot` | Screen capture (with resize support) |
| | `gui_mouse_click` | Click at coordinates (left/right/double) |
| | `gui_mouse_move` | Move the mouse |
| | `gui_mouse_scroll` | Scroll |
| | `gui_keyboard_type` | Text input (Unicode support) |
| | `gui_keyboard_key` | Send a key/keyboard shortcut |
| | `gui_get_mouse_position` | Get mouse coordinates |
| | `gui_get_screen_size` | Get screen resolution |
| **UI Elements** | `ui_get_elements` | Get the accessibility tree |
| | `ui_click_element` | Click by name/role |
| | `ui_set_value` | Set a text field's value |
| | `ui_get_focused` | Get the focused element |
| **Files** | `file_read` | Read a file |
| | `file_write` | Write a file |
| | `file_list` | List a directory |
| | `file_delete` | Delete a file (Trash-aware) |
| | `file_move` | Move/rename a file |
| | `file_info` | Get file information |
| **Apps** | `app_open` | Launch an app |
| | `app_quit` | Quit an app (with force-quit support) |
| | `app_list_running` | List running apps |
| | `app_activate` | Bring an app to the foreground |
| | `app_list_windows` | List windows |
| | `clipboard_get` | Get clipboard contents |
| | `clipboard_set` | Set clipboard contents |
| | `app_open_url` | Open a URL in the browser |
| **Admin** | `admin_status` | Check server status |
| | `admin_kill_switch` | Emergency stop |
| | `admin_caffeinate` | Control sleep prevention |
| | `admin_view_log` | View the audit log |

## Security

- **Bearer token authentication** — an API key is required for every request
- **Dangerous command detection** — 18 patterns including `rm -rf /`, `mkfs`, `dd`, `shutdown`, `reboot`, `curl|sh` are blocked automatically (override with `confirm_dangerous=true`)
- **Audit logging** — every tool call is recorded as JSONL, split by day
- **Emergency stop** — `admin_kill_switch` immediately terminates all sessions
- **Cloudflare Tunnel** — no port forwarding, TLS-encrypted
- **API key rotation** — regenerate instantly from the Settings window

## Testing

```bash
npm test                  # Run all 673 tests
npm run test:unit         # 273 unit tests
npm run test:integration  # 400 integration tests
```

Swift tests (102 logic tests):
```bash
cd app && swift Tests/TestRunner.swift
```

## Configuration files

```
~/.mac-remote-mcp/
├── .env                  # Configuration (API key, ports, tunnel, etc.)
└── logs/
    ├── app.log           # App log
    ├── audit-YYYY-MM-DD.log  # Audit log (JSONL)
    ├── server.stdout.log
    ├── server.stderr.log
    └── tunnel.stderr.log
```

### `.env` settings

```bash
MCP_API_KEY=xxxx                    # API key (auto-generated)
PORT=3000                           # MCP server port
PLAYWRIGHT_PORT=3001                # Playwright port
PROXY_PORT=3002                     # Auth proxy port
AUTO_START=false                    # Auto-start all services
CLOUDFLARE_TUNNEL_TOKEN=            # Tunnel token (blank = Quick Tunnel)
TUNNEL_HOSTNAME=                    # Hostname for the fixed URL
```

## Lessons learned — Apple Notarization

Notes on problems encountered (and their solutions) while getting this project through Apple Notarization.

### Problem 1: "The signature of the binary is invalid"

**Symptom:** `codesign --verify --strict` passes locally, but the Apple Notarization Service rejects the binary.

**Cause:** Signing in two passes breaks the bundle's Sealed Resources.

```bash
# ❌ Bad: signing the main binary, then the bundle, as two separate passes
codesign --sign "..." App.app/Contents/MacOS/App  # 1
codesign --sign "..." App.app                     # 2 ← this breaks the signature from step 1
```

**Fix:** Sign in a single pass with `--deep`.

```bash
# ✅ Correct: single-pass signing
codesign --force --deep --options runtime --timestamp \
  --entitlements Entitlements.plist \
  --sign "Developer ID Application: ..." App.app
```

### Problem 2: Broken signature inside the DMG

**Cause:** `cp -r` does not preserve macOS extended attributes.

```bash
# ❌ cp -r → breaks the signature
# ✅ ditto → preserves the signature and extended attributes
ditto App.app dmg-contents/App.app
ditto -c -k --keepParent App.app App.zip
```

### Problem 3: Missing entitlements

Because node.js runs as a child process, the following entitlements are required:

```xml
<key>com.apple.security.cs.allow-unsigned-executable-memory</key><true/>
<key>com.apple.security.cs.disable-library-validation</key><true/>
<key>com.apple.security.automation.apple-events</key><true/>
```

### Problem 4: Long wait on the first Notarization submission

The first submission from a new Developer ID gets a thorough review from Apple and can take several hours to 24 hours. Once accepted, subsequent submissions take 1-2 minutes.

### Problem 5: Comma formatting with `NSTextField.integerValue`

`integerValue = 3000` → displays as "3,000" → reading it back gives "3". Use `stringValue` instead.

## CI/CD

- **CI** (`ci.yml`): runs Node.js 20/22 tests + Swift compile checks on every push
- **Release** (`release.yml`): tag `v*` → test → build → Developer ID sign → Notarize → DMG+ZIP → GitHub Release

## License

MIT

---

## Related MCP servers

Other MCP servers published by the author (Hori). All can be used from Claude.ai / Cursor / ChatGPT and other MCP clients.

| Server | Tools | Description |
|:--|:--:|:--|
| **[b2cloud-api](https://github.com/DaisukeHori/b2cloud-api)** | 14 | Yamato B2Cloud shipping label API/MCP |
| **[cloudflare-mcp](https://github.com/DaisukeHori/cloudflare-mcp)** | 69 | Cloudflare integration (Tunnel/DNS/Workers/Pages/R2/KV/SSL/Access) |
| **[hubspot-ma-mcp](https://github.com/DaisukeHori/hubspot-ma-mcp)** | 128 | HubSpot MA (CRM/Marketing/Knowledge Store) |
| **[msgraph-mcp-server](https://github.com/DaisukeHori/msgraph-mcp-server)** | 48 | Microsoft Graph API (Exchange/Teams/OneDrive/SharePoint) |
| **[playwright-devtools-mcp](https://github.com/DaisukeHori/playwright-devtools-mcp)** | 57 | Playwright + Chrome DevTools (browser automation) |
| **[proxmox-mcp-server](https://github.com/DaisukeHori/proxmox-mcp-server)** | 35 | Proxmox VE virtualization control |
| **[printer-mcp-server](https://github.com/DaisukeHori/printer-mcp-server)** | — | CUPS network printer control (Kyocera TASKalfa) |
| **[yamato-printer-mcp-server](https://github.com/DaisukeHori/yamato-printer-mcp-server)** | — | Yamato shipping label thermal printer (Raspberry Pi + WS-420B) |
| **[ssh-mcp-server](https://github.com/DaisukeHori/ssh-mcp-server)** | 10 | SSH client (session management/async commands) |
| **mac-remote-mcp** ← you are here | 34 | macOS remote control (Shell/GUI/Files/Apps) |
| **[gemini-image-mcp](https://github.com/DaisukeHori/gemini-image-mcp)** | 4 | Gemini/Imagen image generation |
| **[runpod-mcp](https://github.com/DaisukeHori/runpod-mcp)** | 36 | RunPod GPU FaaS (Pods/Endpoints/Jobs) |
| **[firecrawl-mcp](https://github.com/DaisukeHori/firecrawl-mcp)** | — | Firecrawl self-hosted web scraping |
| **[ad-ops-mcp](https://github.com/DaisukeHori/ad-ops-mcp)** | 62 | Ad operations automation (Google Ads/Meta/GBP/X) |
