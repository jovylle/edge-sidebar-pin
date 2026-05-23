#Requires -Version 5.1
<#
.SYNOPSIS
  Repoint an existing Microsoft Edge sidebar slot to any site (presets or custom URL).

.DESCRIPTION
  Edge retired "Add app" for new sidebar pins. This edits an existing user_generated
  slot (ChatGPT, Copilot, Twitch, etc.) so it opens your URL instead.

  Presets include Messenger (/messenger_web avoids hub URL cleanup). Use -Url for
  anything else. Avoid edge://restart after replacing a Copilot slot.

.PARAMETER Site
  Shorthand: preset name (e.g. Messenger) or a full https:// URL.

.PARAMETER Preset
  Built-in site: Messenger, WhatsApp, Telegram, Discord, Instagram, Spotify, Slack, Teams

.PARAMETER Url
  Custom URL when not using -Preset.

.PARAMETER Name
  Sidebar label for -Url (default: hostname).

.PARAMETER Target
  Which existing slot to replace (Auto, Copilot, Twitch, …, First).

.PARAMETER List
  Show slots; Edge can stay open.

.PARAMETER Pick
  Choose slot from a numbered menu.

.PARAMETER Restore
  Restore Preferences from last backup.

.PARAMETER Wizard
  Guided flow: list slots, pick slot and site, confirm, then pin.

.PARAMETER FullLog
  Verbose diagnostics, full errors on failure, and a transcript under %TEMP%\edge-sidebar-pin.

.EXAMPLE
  .\Start.cmd
  .\Pin.cmd Messenger
  .\Pin.cmd "https://example.com/" "My app"
  powershell -File .\Edge-Set-SidebarApp.ps1 -List
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string] $Site,

    [ValidateSet(
        'Messenger', 'WhatsApp', 'Telegram', 'Discord', 'Instagram', 'Spotify', 'Slack', 'Teams'
    )]
    [string] $Preset,

    [string] $Url,
    [string] $Name,

    [ValidateSet(
        'Auto', 'Copilot', 'Twitch', 'Discord', 'WhatsApp', 'Telegram',
        'ChatGPT', 'Claude', 'Gemini', 'Grok', 'Instagram', 'Spotify', 'First'
    )]
    [string] $Target = 'Auto',

    [string] $Id,
    [string] $Profile = 'Default',

    [switch] $List,
    [switch] $Pick,
    [switch] $Restore,
    [switch] $Wizard,
    [switch] $FullLog
)

$ErrorActionPreference = 'Stop'

$script:TranscriptPath = $null

if ($FullLog) {
    $VerbosePreference = 'Continue'
    $DebugPreference = 'Continue'
    $logDir = Join-Path $env:TEMP 'edge-sidebar-pin'
    $null = New-Item -ItemType Directory -Force -Path $logDir
    $script:TranscriptPath = Join-Path $logDir ('run-{0:yyyyMMdd-HHmmss}.log' -f (Get-Date))
    Start-Transcript -Path $script:TranscriptPath -Force | Out-Null
    Write-Host "Full logging on. Transcript: $($script:TranscriptPath)"
    Write-Host ''
}

function Stop-TranscriptIfOpen {
    if (-not $script:TranscriptPath) { return }
    Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
    $script:TranscriptPath = $null
}

function Exit-WithCode {
    param([int] $Code = 0)
    Stop-TranscriptIfOpen
    exit $Code
}

function Write-Diag {
    param([string] $Message)
    if ($FullLog) {
        Write-Host "[diag] $Message" -ForegroundColor DarkGray
    }
}

trap {
    Write-Host ''
    Write-Host ('ERROR: {0}' -f $_.Exception.Message) -ForegroundColor Red
    if ($FullLog) {
        Write-Host ''
        Write-Host '--- Full error ---' -ForegroundColor Yellow
        if ($_.Exception.InnerException) {
            Write-Host ('Inner: {0}' -f $_.Exception.InnerException.Message)
        }
        if ($_.CategoryInfo) {
            Write-Host ('Category: {0}' -f $_.CategoryInfo.Category)
        }
        if ($_.TargetObject) {
            Write-Host ('Target: {0}' -f $_.TargetObject)
        }
        if ($_.ScriptStackTrace) {
            Write-Host ''
            Write-Host 'Script stack:'
            Write-Host $_.ScriptStackTrace
        }
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
            Write-Host ''
            Write-Host 'Details:'
            Write-Host $_.ErrorDetails.Message
        }
        if ($script:TranscriptPath) {
            Write-Host ''
            Write-Host "Transcript: $($script:TranscriptPath)"
        }
    }
    else {
        Write-Host 'Tip: Start.cmd -FullLog (or Pin.cmd -FullLog) for details and a saved log.'
    }
    Stop-TranscriptIfOpen
    exit 1
}

#region Data

$Script:Presets = @{
    Messenger  = @{
        Url             = 'https://www.messenger.com/messenger_web'
        Name            = 'Messenger'
        DeviceEmulation = 'mobile_touch'
    }
    WhatsApp   = @{
        Url             = 'https://web.whatsapp.com/'
        Name            = 'WhatsApp'
        DeviceEmulation = 'mobile_touch'
    }
    Telegram   = @{
        Url             = 'https://web.telegram.org/'
        Name            = 'Telegram'
        DeviceEmulation = 'mobile_touch'
    }
    Discord    = @{
        Url             = 'https://discord.com/app'
        Name            = 'Discord'
        DeviceEmulation = 'mobile_touch'
    }
    Instagram  = @{
        Url             = 'https://www.instagram.com/'
        Name            = 'Instagram'
        DeviceEmulation = 'mobile_touch'
    }
    Spotify    = @{
        Url             = 'https://open.spotify.com/'
        Name            = 'Spotify'
        DeviceEmulation = 'none'
    }
    Slack      = @{
        Url             = 'https://app.slack.com/client'
        Name            = 'Slack'
        DeviceEmulation = 'none'
    }
    Teams      = @{
        Url             = 'https://teams.microsoft.com/'
        Name            = 'Teams'
        DeviceEmulation = 'none'
    }
}

$PrefPath = Join-Path $env:LOCALAPPDATA "Microsoft\Edge\User Data\$Profile\Preferences"
$BackupPath = "$PrefPath.bak.edge-sidebar-pin"

$CommonTargets = @(
    @{ Key = 'Copilot';   UrlMatch = 'github.com/copilot'; NameMatch = 'copilot' }
    @{ Key = 'Twitch';    UrlMatch = 'twitch.tv' }
    @{ Key = 'Discord';   UrlMatch = 'discord.com' }
    @{ Key = 'WhatsApp';  UrlMatch = 'web.whatsapp.com' }
    @{ Key = 'Telegram';  UrlMatch = 'web.telegram.org' }
    @{ Key = 'ChatGPT';   UrlMatch = 'chatgpt.com' }
    @{ Key = 'Claude';    UrlMatch = 'claude.ai' }
    @{ Key = 'Gemini';    UrlMatch = 'gemini.google' }
    @{ Key = 'Grok';      UrlMatch = 'grok.com' }
    @{ Key = 'Instagram'; UrlMatch = 'instagram.com' }
    @{ Key = 'Spotify';   UrlMatch = 'open.spotify.com' }
)

#endregion

#region Edge I/O

function Stop-EdgeBrowser {
    if (Get-Process msedge -ErrorAction SilentlyContinue) {
        Write-Host 'Closing Microsoft Edge...'
        if ($FullLog) {
            taskkill /F /IM msedge.exe
        }
        else {
            taskkill /F /IM msedge.exe 2>$null | Out-Null
        }
        Start-Sleep -Seconds 2
    }
    if (Get-Process msedge -ErrorAction SilentlyContinue) {
        throw 'Edge is still running. Close all windows and try again.'
    }
}

function Resolve-SiteParameter {
    if (-not $Site) { return }
    if ($Preset -or $Url) {
        throw 'Use either -Site, or -Preset/-Url, not both.'
    }
    $key = $Script:Presets.Keys | Where-Object { $_ -ieq $Site } | Select-Object -First 1
    if ($key) {
        $script:Preset = $key
        return
    }
    if ($Site -match '^https?://') {
        $script:Url = $Site
        return
    }
    throw "Unknown preset '$Site'. Known: $($Script:Presets.Keys -join ', '). Or pass a full https:// URL."
}

function Get-Destination {
    if ($Preset) {
        if (-not $Script:Presets.ContainsKey($Preset)) {
            throw "Unknown preset: $Preset"
        }
        return $Script:Presets[$Preset].Clone()
    }
    if ($Url) {
        $label = if ($Name) { $Name } else {
            try { ([uri]$Url).Host } catch { 'Sidebar app' }
        }
        return @{
            Url             = $Url
            Name            = $label
            DeviceEmulation = 'mobile_touch'
        }
    }
    return $null
}

#endregion

#region UI

function Write-NoSlotsHelp {
    param([string] $ProfileName, [string] $PreferencesPath)

    Write-Host ''
    Write-Host 'Cannot continue — no custom sidebar slots in this Edge profile.'
    Write-Host ''
    Write-Host 'Why:'
    Write-Host '  Microsoft Edge removed "Add app" for new sidebar pins.'
    Write-Host '  This tool repoints a slot you already have (Copilot, Twitch, ChatGPT, …).'
    Write-Host ''
    Write-Host 'You need at least one app still pinned in the sidebar from before that change.'
    Write-Host 'If your sidebar is empty of third-party apps, this method cannot work yet.'
    Write-Host ''
    Write-Host "Profile checked: $ProfileName"
    Write-Host "Preferences:    $PreferencesPath"
    Write-Host ''
    Write-Host 'What to try:'
    Write-Host '  - Open Edge and check the sidebar for Copilot, Twitch, or similar icons.'
    Write-Host '  - Wrong profile? edge://settings -> Profiles -> note the folder name, then run:'
    Write-Host '      Start.cmd -Profile ProfileName'
    Write-Host ''
    Write-Host 'Undo after a successful pin: Restore.cmd'
}

function Write-WizardIntro {
    Write-Host ''
    Write-Host '=== Edge sidebar pin (guided) ==='
    Write-Host ''
    Write-Host 'This repoints an existing sidebar slot to another site (Messenger, WhatsApp, …).'
    Write-Host 'Edge can stay open while we list your slots; it will close when you confirm the pin.'
    Write-Host ''
    Write-Host 'Notes:'
    Write-Host '  - A backup is saved before each change (Restore.cmd to undo).'
    Write-Host '  - After replacing Copilot, avoid edge://restart — open Edge normally.'
    Write-Host '  - Personal profiles only; not supported by Microsoft.'
    Write-Host ''
}

function Show-SlotsTable {
    param(
        [string] $ProfileName,
        [string] $PreferencesPath,
        [array] $Apps
    )

    Write-Host "Profile: $ProfileName"
    Write-Host "Path:    $PreferencesPath`n"
    Write-Host 'Your sidebar slots (pick one to repoint):'
    $Apps | Format-Table Preset, Name, Url -AutoSize
    Write-Host ''
}

function Read-SlotChoice {
    param([array] $Apps)

    for ($i = 0; $i -lt $Apps.Count; $i++) {
        $a = $Apps[$i]
        $tag = if ($a.Preset) { "[$($a.Preset)]" } else { '[custom]' }
        Write-Host "  [$i] $tag $($a.Name)"
        Write-Host "       $($a.Url)"
    }
    Write-Host ''
    $choice = Read-Host "Slot number (0-$($Apps.Count - 1))"
    if (-not $choice -match '^\d+$') { throw 'Enter a slot number from the list.' }
    $idx = [int]$choice
    if ($idx -lt 0 -or $idx -ge $Apps.Count) { throw 'Invalid slot number.' }
    return $Apps[$idx]
}

function Read-DestinationFromMenu {
    $presetNames = @($Script:Presets.Keys | Sort-Object)
    Write-Host ''
    Write-Host 'Site to open in that slot:'
    for ($i = 0; $i -lt $presetNames.Count; $i++) {
        $key = $presetNames[$i]
        Write-Host "  [$i] $key - $($Script:Presets[$key].Url)"
    }
    $customIdx = $presetNames.Count
    Write-Host "  [$customIdx] Custom URL"
    Write-Host ''
    $choice = Read-Host 'Number, preset name, or full https:// URL'
    if (-not $choice) { throw 'No site entered.' }

    if ($choice -match '^\d+$') {
        $idx = [int]$choice
        if ($idx -ge 0 -and $idx -lt $presetNames.Count) {
            return $Script:Presets[$presetNames[$idx]].Clone()
        }
        if ($idx -ne $customIdx) { throw 'Invalid site number.' }
        $choice = Read-Host 'Custom URL (https://...)'
    }

    $key = $Script:Presets.Keys | Where-Object { $_ -ieq $choice.Trim() } | Select-Object -First 1
    if ($key) { return $Script:Presets[$key].Clone() }

    if ($choice -notmatch '^https?://') {
        throw 'Enter a preset number/name or a URL starting with https://'
    }
    $label = Read-Host 'Sidebar label (Enter for hostname)'
    return @{
        Url             = $choice.Trim()
        Name            = if ($label) { $label } else { ([uri]$choice.Trim()).Host }
        DeviceEmulation = 'mobile_touch'
    }
}

function Confirm-PinPlan {
    param(
        $App,
        [hashtable] $Dest
    )

    Write-Host ''
    Write-Host '--- Confirm ---'
    Write-Host "  Slot:  $($App.Name)"
    Write-Host "         $($App.Url)"
    Write-Host "  Site:  $($Dest.Name)"
    Write-Host "         $($Dest.Url)"
    Write-Host ''
    Write-Host 'Microsoft Edge will close. Preferences backup will be written.'
    $answer = Read-Host 'Continue? (Y/n)'
    if ($answer -match '^[Nn]') {
        Write-Host 'Cancelled. No changes made.'
        Exit-WithCode 0
    }
}

function Invoke-ApplyPin {
    param(
        $App,
        [hashtable] $Dest,
        [string] $SlotId,
        [string] $Raw,
        [string] $PrefPath,
        [string] $BackupPath
    )

    if ($App.Url -eq $Dest.Url) {
        Write-Host "Already set: $($Dest.Name) -> $($Dest.Url)"
        return
    }

    Stop-EdgeBrowser

    $pattern = '(?s)"' + [regex]::Escape($SlotId) + '":\{"device_emulation":"[^"]+".*?"url":"' + [regex]::Escape($App.Url) + '"[^}]*\}'
    Write-Diag "Slot id: $SlotId"
    Write-Diag "Match url: $($App.Url)"
    if ($FullLog) {
        $preview = if ($pattern.Length -gt 200) { $pattern.Substring(0, 200) + '...' } else { $pattern }
        Write-Diag "Regex: $preview"
    }
    if ($Raw -notmatch $pattern) {
        throw "Could not find Preferences block for: $($App.Name)"
    }

    $oldBlock = $Matches[0]
    $newBlock = New-SidebarEntry -SlotId $SlotId -Dest $Dest
    $oldName = $App.Name

    Copy-Item -LiteralPath $PrefPath -Destination $BackupPath -Force
    Write-Host "Backup: $BackupPath"
    Write-Host ('Replacing: {0}' -f $oldName)
    Write-Host ('  Was: {0}' -f $App.Url)
    Write-Host ('  Now: {0} ({1})' -f $Dest.Url, $Dest.Name)

    $Raw = $Raw.Replace($oldBlock, $newBlock)

    $orderPattern = '"' + [regex]::Escape($SlotId) + '":\{"name":"' + '[^"]+' + '","pos":"(\d+)"\}'
    $orderReplace = '"' + $SlotId + '":{"name":"' + $Dest.Name + '","pos":"' + '$1' + '"}'
    $Raw = ([regex]::new($orderPattern)).Replace($Raw, $orderReplace, 1)

    $escapedName = [regex]::Escape($oldName)
    if ($Raw -match '"order_list":\[[^\]]+\]') {
        $orderListBlock = $Matches[0]
        if ($orderListBlock -match $escapedName) {
            $Raw = $Raw.Replace($orderListBlock, ($orderListBlock -replace $escapedName, $Dest.Name))
        }
    }

    Write-Diag 'Validating JSON before write...'
    try {
        $null = $Raw | ConvertFrom-Json
    }
    catch {
        if ($FullLog) {
            Write-Diag "JSON error at offset $($_.Exception.Message)"
        }
        throw "Preferences JSON invalid after edit: $($_.Exception.Message)"
    }
    [System.IO.File]::WriteAllText($PrefPath, $Raw)
    Write-Diag "Wrote: $PrefPath ($((Get-Item -LiteralPath $PrefPath).Length) bytes)"

    Write-Host ''
    Write-Host "Done. Slot $SlotId is now $($Dest.Name)."
    Write-Host 'Open Edge normally (not edge://restart), especially if you replaced Copilot.'
    Write-Host "Undo: Restore.cmd"
}

function Invoke-SidebarWizard {
    param(
        [array] $Apps,
        [string] $Raw,
        [string] $PrefPath,
        [string] $BackupPath,
        [string] $ProfileName
    )

    Write-WizardIntro

    if ($Apps.Count -eq 0) {
        Write-NoSlotsHelp -ProfileName $ProfileName -PreferencesPath $PrefPath
        Exit-WithCode 1
    }

    Show-SlotsTable -ProfileName $ProfileName -PreferencesPath $PrefPath -Apps $Apps
    $app = Read-SlotChoice -Apps $Apps
    $dest = Read-DestinationFromMenu
    Confirm-PinPlan -App $app -Dest $dest
    Invoke-ApplyPin -App $app -Dest $dest -SlotId $app.Id -Raw $Raw -PrefPath $PrefPath -BackupPath $BackupPath
}

#endregion

#region Preferences parsing

function Get-SidebarApps {
    param([string] $Raw)

    Write-Diag "Preferences length: $($Raw.Length) chars"

    if ($Raw -notmatch '"user_generated":\{(.+?)\},"user_generated_index"') {
        Write-Diag 'No user_generated block matched (empty sidebar or newer Edge format).'
        return @()
    }

    $block = $Matches[1]
    Write-Diag "user_generated block length: $($block.Length) chars"
    [regex]::Matches(
        $block,
        '"([0-9a-f-]{36})":\{"device_emulation":"([^"]+)"[^}]*"name":"([^"]+)"[^}]*"url":"([^"]+)"'
    ) | ForEach-Object {
        $appId = $_.Groups[1].Value
        $url = $_.Groups[4].Value
        $appName = $_.Groups[3].Value

        $matched = $null
        foreach ($t in $CommonTargets) {
            if ($url -like "*$($t.UrlMatch)*") { $matched = $t.Key; break }
            if ($t.NameMatch -and $appName -like "*$($t.NameMatch)*") { $matched = $t.Key; break }
        }

        [PSCustomObject]@{
            Id     = $appId
            Mode   = $_.Groups[2].Value
            Name   = $appName
            Url    = $url
            Preset = $matched
        }
    } | ForEach-Object -Begin { $script:DiagSlotCount = 0 } -Process {
        $script:DiagSlotCount++
        $_
    } -End {
        Write-Diag "Parsed $($script:DiagSlotCount) sidebar slot(s)."
    }
}

function Get-IndexOrder {
    param([string] $Raw)
    if ($Raw -match '"user_generated_index":\["([0-9a-f-,\-]+)"\]') {
        return $Matches[1].Split(',') | ForEach-Object { $_.Trim('"') }
    }
    return @()
}

function Resolve-TargetApp {
    param(
        [array] $Apps,
        [string] $Raw,
        [string] $TargetName,
        [string] $ExplicitId,
        [string] $ExcludeUrl
    )

    if ($ExplicitId) {
        return $Apps | Where-Object { $_.Id -eq $ExplicitId } | Select-Object -First 1
    }

    $candidates = if ($ExcludeUrl) {
        $Apps | Where-Object { $_.Url -ne $ExcludeUrl }
    } else { $Apps }

    if ($TargetName -eq 'First') {
        $order = Get-IndexOrder -Raw $Raw
        foreach ($id in $order) {
            $hit = $candidates | Where-Object { $_.Id -eq $id } | Select-Object -First 1
            if ($hit) { return $hit }
        }
        return $candidates | Select-Object -First 1
    }

    if ($TargetName -ne 'Auto') {
        $rule = $CommonTargets | Where-Object { $_.Key -eq $TargetName } | Select-Object -First 1
        if ($rule) {
            $hit = $candidates | Where-Object {
                $_.Url -like "*$($rule.UrlMatch)*" -or
                ($rule.NameMatch -and $_.Name -like "*$($rule.NameMatch)*")
            } | Select-Object -First 1
            if ($hit) { return $hit }
        }
        throw "No sidebar app matching -Target $TargetName. Run Start.cmd to list slots."
    }

    foreach ($t in $CommonTargets) {
        $hit = $candidates | Where-Object {
            $_.Url -like "*$($t.UrlMatch)*" -or
            ($t.NameMatch -and $_.Name -like "*$($t.NameMatch)*")
        } | Select-Object -First 1
        if ($hit) {
            Write-Host "Auto picked slot: $($t.Key) ($($hit.Name))"
            return $hit
        }
    }

    $order = Get-IndexOrder -Raw $Raw
    foreach ($id in $order) {
        $hit = $candidates | Where-Object { $_.Id -eq $id } | Select-Object -First 1
        if ($hit) {
            Write-Host "Auto picked first pinned slot: $($hit.Name)"
            return $hit
        }
    }

    return $candidates | Select-Object -First 1
}

function New-SidebarEntry {
    param(
        [string] $SlotId,
        [hashtable] $Dest
    )
    $icon = 'edge://favicon2/?size=32&scaleFactor=2x&pageUrl=' + $Dest.Url + '/&showFallbackMonogram=1'
    return (
        '"' + $SlotId + '":{' +
        '"device_emulation":"' + $Dest.DeviceEmulation + '",' +
        '"icon_url":"' + $icon + '",' +
        '"id":"' + $SlotId + '",' +
        '"name":"' + $Dest.Name + '",' +
        '"navigable":false,' +
        '"notificationsEnabled":true,' +
        '"preferred_side_pane_width":901,' +
        '"url":"' + $Dest.Url + '"' +
        '}'
    )
}

#endregion

#region Main

Resolve-SiteParameter

Write-Diag "Profile: $Profile"
Write-Diag "Preferences: $PrefPath"

if (-not (Test-Path -LiteralPath $PrefPath)) {
    throw "Preferences not found: $PrefPath`nUse -Profile if you use another Edge profile."
}

if ($Restore) {
    Stop-EdgeBrowser
    if (-not (Test-Path -LiteralPath $BackupPath)) {
        throw "No backup found: $BackupPath"
    }
    Copy-Item -LiteralPath $BackupPath -Destination $PrefPath -Force
    Write-Host 'Restored from backup. Start Edge normally (avoid edge://restart on Copilot slots).'
    Exit-WithCode 0
}

$raw = [System.IO.File]::ReadAllText($PrefPath)
$apps = @(Get-SidebarApps -Raw $raw)

if ($List) {
    if ($apps.Count -eq 0) {
        Write-NoSlotsHelp -ProfileName $Profile -PreferencesPath $PrefPath
        Exit-WithCode 1
    }
    Show-SlotsTable -ProfileName $Profile -PreferencesPath $PrefPath -Apps $apps
    Exit-WithCode 0
}

$dest = Get-Destination

if ($Wizard) {
    Invoke-SidebarWizard -Apps $apps -Raw $raw -PrefPath $PrefPath -BackupPath $BackupPath -ProfileName $Profile
    Exit-WithCode 0
}

if ($apps.Count -eq 0) {
    Write-NoSlotsHelp -ProfileName $Profile -PreferencesPath $PrefPath
    Exit-WithCode 1
}

if ($Pick) {
    Show-SlotsTable -ProfileName $Profile -PreferencesPath $PrefPath -Apps $apps
    $app = Read-SlotChoice -Apps $apps
    $slotId = $app.Id
    if (-not $dest) {
        $dest = Read-DestinationFromMenu
    }
}
else {
    if (-not $dest) {
        throw 'Specify a site: Pin.cmd Messenger, Pin.cmd <url>, or Start.cmd for guided setup.'
    }
    $app = Resolve-TargetApp -Apps $apps -Raw $raw -TargetName $Target -ExplicitId $Id -ExcludeUrl $dest.Url
    if (-not $app) {
        Show-SlotsTable -ProfileName $Profile -PreferencesPath $PrefPath -Apps $apps
        throw 'Could not resolve a slot to replace. Use Start.cmd or Pin.cmd -Pick.'
    }
    $slotId = $app.Id
}

Invoke-ApplyPin -App $app -Dest $dest -SlotId $slotId -Raw $raw -PrefPath $PrefPath -BackupPath $BackupPath

Exit-WithCode 0

#endregion
