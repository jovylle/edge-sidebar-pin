# Changelog

## [2.1.0] - 2026-05-23

### Changed

- **`Start.cmd`** — single guided flow (list slots → pick slot → pick site → confirm)
- Shared **`_Run.cmd`** launcher (pause + errors) for all entrypoints
- **`Pin.cmd`** with no args runs the same wizard as `Start.cmd`

### Removed

- **`List.cmd`** — listing is part of `Start.cmd`; use `Pin.cmd -List` or `-List` in PowerShell

## [2.0.0] - 2026-05-23

### Changed

- Renamed project to **edge-sidebar-pin** (generic sites, not Messenger-only)
- Main script: `Edge-Set-SidebarApp.ps1` with `-Preset`, `-Url`, `-Name`, positional `Site`
- Launchers: `Pin.cmd`, `Restore.cmd`
- Backup file: `Preferences.bak.edge-sidebar-pin`

### Added

- Presets: Messenger, WhatsApp, Telegram, Discord, Instagram, Spotify, Slack, Teams
- Fixes: regex after `url`, `$list` vs `-List` clash, PS 5.1 `Replace` count

### Removed

- `Edge-Replace-SidebarWithMessenger.ps1`, `Run-*.ps1`, `Run-*.cmd`

## [1.0.0] - 2026-05-23

- Initial Messenger-only release
