# Project context (for contributors / new chat)

Handoff for **edge-sidebar-pin** — repoint existing Microsoft Edge `user_generated` sidebar slots to any URL (presets or custom).

## Repo

- **GitHub:** `jovylle/edge-sidebar-pin`
- **Main script:** `Edge-Set-SidebarApp.ps1`
- **User entrypoints:** `Start.cmd` (wizard), `Pin.cmd` (quick pin), `Restore.cmd`
- **Internal:** `_Run.cmd` — shared PowerShell launcher with pause

## Problem

- Edge sidebar “Add app” retired; UI no longer adds new pins.
- Some hub URLs are stripped on startup if you add them as new slots (e.g. root `https://www.messenger.com/`).
- Pinning official hub IDs via `Preferences` alone is often reverted on launch.

## Solution that works

**Replace an existing `user_generated` sidebar slot** (keep its UUID):

- Set `url`, `name`, `device_emulation` in `Preferences`
- Keep slot in `user_generated_index`, `user_added_trusted`, `show_hub_app_in_sidebar_buttons` = 2

**Messenger-specific:** use `https://www.messenger.com/messenger_web` (not root `/`).

**Copilot slot:** match `github.com/copilot` by URL; block regex must allow fields after `url` (e.g. `web_app_manifest_declared`).

## What failed

| Attempt | Result |
|--------|--------|
| New random UUID + messenger.com | Stripped on Edge start |
| Pin official hub ID | Reverted to unpinned |
| Swap slot to root messenger.com | Slot removed |
| `edge://restart` | Can restore Copilot metadata for that UUID |

## Edge files (Windows)

| File | Role |
|------|------|
| `%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Preferences` | `user_generated`, index, sidebar visibility |
| `Preferences.bak.edge-sidebar-pin` | Auto-backup from script |

Close Edge before editing (`taskkill /F /IM msedge.exe`).

## Script notes

- No hardcoded slot UUIDs — match by URL/name patterns for `-Target`.
- **Do not use variable `$list`** — clashes with `-List` switch in PowerShell.
- Use `[regex]::new($pattern).Replace($raw, $replacement, 1)` not `[regex]::Replace(..., 1)` on PS 5.1.
- `-Wizard` is only set by `Start.cmd` / `Pin.cmd` (no args); do not infer wizard from other flags.

## User-facing caveats

- Need ≥1 existing custom sidebar pin; wizard shows `Write-NoSlotsHelp` and exits if none.
- Avoid `edge://restart` after Copilot replacement.
- May break on Edge updates.
