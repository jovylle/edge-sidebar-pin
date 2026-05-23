# edge-sidebar-pin

Pin **any site** in the Microsoft Edge sidebar after Edge retired “Add app” — by repointing a slot you already have (ChatGPT, Copilot, Twitch, etc.).

**Windows only** · **Double-click `Start.cmd`** · **Not affiliated with Microsoft**

## Why this exists

Microsoft [retired the sidebar app list](https://support.microsoft.com/en-us/edge/streamline-access-to-your-favorite-sites-and-apps-with-sidebar-in-microsoft-edge). You can’t add new apps from the UI anymore.

**What works:** keep an existing `user_generated` slot UUID and change its `url` / `name` in Edge `Preferences`. Some sites need a specific path (e.g. Messenger uses `/messenger_web` so Edge doesn’t strip it).

## Requirements

- Windows 10/11 with Microsoft Edge
- At least **one** custom sidebar app still pinned (from before “Add app” was removed)

## Quick start

```powershell
git clone https://github.com/jovylle/edge-sidebar-pin.git
cd edge-sidebar-pin
```

Double-click **`Start.cmd`** — list your slots, pick one, pick a site, confirm. Edge closes only when you confirm the pin.

| File | Purpose |
|------|---------|
| **`Start.cmd`** | Guided setup (recommended) |
| **`Pin.cmd`** *Site* | Quick pin, e.g. `Pin.cmd Messenger` |
| **`Restore.cmd`** | Undo last change from automatic backup |

No custom sidebar slots? `Start.cmd` explains why and stops.

```bat
Start.cmd
Pin.cmd Messenger
Pin.cmd WhatsApp
Pin.cmd "https://example.com/" "My app"
Pin.cmd Messenger -Target Copilot
Restore.cmd
```

`Pin.cmd` with no arguments runs the same guided flow as `Start.cmd`.

## Presets

| Preset | URL |
|--------|-----|
| Messenger | `https://www.messenger.com/messenger_web` |
| WhatsApp | `https://web.whatsapp.com/` |
| Telegram | `https://web.telegram.org/` |
| Discord | `https://discord.com/app` |
| Instagram | `https://www.instagram.com/` |
| Spotify | `https://open.spotify.com/` |
| Slack | `https://app.slack.com/client` |
| Teams | `https://teams.microsoft.com/` |

Custom site: `Pin.cmd "https://yoursite.com/path" "Label"`

## Advanced (PowerShell)

```powershell
powershell -ExecutionPolicy Bypass -File .\Edge-Set-SidebarApp.ps1 -List
powershell -ExecutionPolicy Bypass -File .\Edge-Set-SidebarApp.ps1 -Preset Messenger -Target Twitch
powershell -ExecutionPolicy Bypass -File .\Edge-Set-SidebarApp.ps1 -Url "https://example.com/" -Name "Example" -Pick
```

| Flag | Description |
|------|-------------|
| `-Wizard` | Guided flow (same as `Start.cmd`) |
| `-List` | Show slots only |
| `-Preset` / positional `Site` | Built-in site |
| `-Url` / `-Name` | Custom site |
| `-Target` | Slot to replace (`Auto`, `Copilot`, `Twitch`, `First`, …) |
| `-Pick` | Pick slot from a menu (with `-Preset` or `-Url`) |
| `-Profile` | Non-default Edge profile |
| `-Restore` | Restore backup |

## Caveats

- Backup: `Preferences.bak.edge-sidebar-pin` before each pin
- **Avoid `edge://restart`** on Copilot-replaced slots
- Edge updates may change behavior; re-run or `Restore.cmd`
- Personal profiles only; not supported by Microsoft

## Files

```
edge-sidebar-pin/
  Edge-Set-SidebarApp.ps1
  Start.cmd  Pin.cmd  Restore.cmd
  README.md  CONTEXT.md  CHANGELOG.md  LICENSE
```

## License

MIT — see [LICENSE](LICENSE).
