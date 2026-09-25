<#
.SYNOPSIS
Starts a fresh desktop first-play session with the pinned Godot build.

.DESCRIPTION
Calls SavedGame.boot with the supplied signed int64 seed in a new per-condition save directory,
then opens the real AppRoot on that directory. Manual and Auto conditions use the same UI; Auto
starts with the existing auto-clear setting enabled. Saves are retained and existing target paths
are refused. Paths must be new children of tools/out/desktop_playtests, so user://save_v1 is never
used. No Android installation or device interaction occurs.

Matching seeds and matching engine/rule/catalog/supply configuration guarantee the same initial
queue and checkpoint. This does not guarantee matching later supplies: board-aware generation can
diverge after the sessions reach different board states.

.PARAMETER Seed
Canonical signed int64 decimal passed to the production GameSession initial checkpoint.

.PARAMETER SaveDirectory
An absolute, not-yet-existing child directory under tools/out/desktop_playtests. Use different
paths for Manual and Auto so both saves remain preserved.

.PARAMETER Condition
Manual or Auto. Both conditions launch the production AppRoot and the same PuzzleScreen UI.

.PARAMETER HeadlessSmoke
Runs one bounded headless AppRoot boot and exits after checking the screen and seeded save wiring.

.PARAMETER Probe
Creates manual and auto child saves under SaveDirectory, verifies initial queue/checkpoint equality
and isolation, then confirms AppRoot can resume one session. The probe saves are preserved.

.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File tools/start_desktop_playtest.ps1 -Seed 20260923 -SaveDirectory C:\DEV\Games\Blocktower\tools\out\desktop_playtests\manual_20260923

.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File tools/start_desktop_playtest.ps1 -Seed 20260923 -Condition Auto -SaveDirectory C:\DEV\Games\Blocktower\tools\out\desktop_playtests\auto_20260923

.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File tools/start_desktop_playtest.ps1 -Seed 20260923 -SaveDirectory C:\DEV\Games\Blocktower\tools\out\desktop_playtests\smoke_20260923 -HeadlessSmoke

.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File tools/start_desktop_playtest.ps1 -Seed 20260923 -SaveDirectory C:\DEV\Games\Blocktower\tools\out\desktop_playtests\probe_20260923 -Probe

.NOTES
Metadata contains only the seed, rule/engine/supply identity, isolated save path, and local source
fingerprint. There is no network telemetry or participant information. Existing saves are never
deleted or resumed; choose a new path for each run.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Seed,
    [Parameter(Mandatory = $true)]
    [string]$SaveDirectory,
    [ValidateSet('Manual', 'Auto')]
    [string]$Condition = 'Manual',
    [string]$GodotExe,
    [switch]$HeadlessSmoke,
    [switch]$Probe
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

if ($HeadlessSmoke -and $Probe) {
    Stop-WithFailure 'Choose either -HeadlessSmoke or -Probe, not both.'
}

[long]$parsedSeed = 0
$seedStyle = [System.Globalization.NumberStyles]::AllowLeadingSign
$culture = [System.Globalization.CultureInfo]::InvariantCulture
if ($Seed -cnotmatch '\A(?:0|-?[1-9][0-9]*)\z' -or
    -not [long]::TryParse($Seed, $seedStyle, $culture, [ref]$parsedSeed)) {
    Stop-WithFailure 'Seed must be a canonical signed int64 decimal, such as 0, 42, or -42.'
}

$gameSessionPath = Join-Path $script:GameDir 'scripts\core\game_session.gd'
$generatorConfigPath = Join-Path $script:GameDir 'data\piece_generator_low_single.tres'
$gameSessionText = Get-Content -LiteralPath $gameSessionPath -Raw -Encoding UTF8
$generatorConfigText = Get-Content -LiteralPath $generatorConfigPath -Raw -Encoding UTF8
if ($gameSessionText -notmatch '"rule_version"\s*:\s*"([^"]+)"') {
    Stop-WithFailure 'Could not read the production rule version from GameSession.'
}
$ruleVersion = $Matches[1]
if ($generatorConfigText -notmatch '(?m)^catalog_version\s*=\s*"([^"]+)"') {
    Stop-WithFailure 'Could not read the catalog version from the default generator config.'
}
$catalogVersion = $Matches[1]
if ($generatorConfigText -notmatch '(?m)^supply_policy_version\s*=\s*"([^"]+)"') {
    Stop-WithFailure 'Could not read the supply policy version from the default generator config.'
}
$supplyPolicyVersion = $Matches[1]

$runtimeFiles = @(
    'project.godot',
    'scenes\app.tscn',
    'data\piece_generator_default.tres',
    'data\piece_generator_low_single.tres',
    'scripts\application\app_root.gd',
    'scripts\application\saved_game.gd',
    'scripts\core\game_session.gd',
    'scripts\core\generation\piece_generator.gd',
    'scripts\core\generation\piece_generator_config.gd',
    'scripts\presentation\puzzle_screen.gd',
    'scripts\presentation\presentation_controller.gd'
)
$sourceLines = New-Object System.Collections.Generic.List[string]
foreach ($relative in $runtimeFiles) {
    $sourcePath = Join-Path $script:GameDir $relative
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        Stop-WithFailure ("Build fingerprint source is missing: {0}" -f $relative)
    }
    $sourceLines.Add(("{0} {1}" -f $relative.Replace('\', '/'), (Get-FileSha256 $sourcePath)))
}
$sourceBytes = [System.Text.Encoding]::UTF8.GetBytes(($sourceLines.ToArray() -join "`n") + "`n")
$sourceHasher = [System.Security.Cryptography.SHA256]::Create()
try {
    $sourceHash = -join ($sourceHasher.ComputeHash($sourceBytes) | ForEach-Object { $_.ToString('x2') })
} finally {
    $sourceHasher.Dispose()
}
$buildIdentifier = 'local-runtime-source-manifest-sha256:' + $sourceHash

$allowedRoot = [System.IO.Path]::GetFullPath((Join-Path $script:RepoRoot 'tools\out\desktop_playtests')).TrimEnd('\', '/')
try {
    if (-not [System.IO.Path]::IsPathRooted($SaveDirectory)) {
        Stop-WithFailure 'SaveDirectory must be an absolute local path under tools/out/desktop_playtests.'
    }
    $savePath = [System.IO.Path]::GetFullPath($SaveDirectory).TrimEnd('\', '/')
} catch {
    Stop-WithFailure 'SaveDirectory is not a valid local path.'
}
$allowedPrefix = $allowedRoot + [System.IO.Path]::DirectorySeparatorChar
if (-not $savePath.StartsWith($allowedPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    Stop-WithFailure 'SaveDirectory must be a child of tools/out/desktop_playtests; user:// and Android saves are never used.'
}
function Assert-NoReparsePointAncestor([string]$Path, [string]$Root) {
    $current = [System.IO.DirectoryInfo]([System.IO.Path]::GetDirectoryName($Path))
    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $crossedRoot = $false
    while ($null -ne $current) {
        $currentFull = $current.FullName.TrimEnd('\', '/')
        # The requested child (and possibly new intermediate parents) do not exist yet;
        # DirectoryInfo reports Attributes=-1 for those paths, so inspect the nearest
        # existing ancestor before any directory is created by SavedGame.boot.
        $exists = Test-Path -LiteralPath $currentFull -PathType Container
        if ($exists -and ($current.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
            Stop-WithFailure ("SaveDirectory parent is a reparse point; refusing redirected storage: {0}" -f $currentFull)
        }
        if ($currentFull.Equals($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
            # Keep walking above the root so an existing tools/out junction is also
            # rejected; a missing root is accepted once its existing ancestors pass.
            $crossedRoot = $true
        }
        $current = $current.Parent
    }
    if (-not $crossedRoot) {
        Stop-WithFailure 'Could not resolve the save directory parent chain back to tools/out/desktop_playtests.'
    }
}
Assert-NoReparsePointAncestor $savePath $allowedRoot
if (Test-Path -LiteralPath $savePath) {
    Stop-WithFailure ("SaveDirectory already exists and reuse is refused: {0}" -f $savePath)
}

$provenance = Read-Provenance
$verificationGodot = Resolve-GodotExe $GodotExe
$engineVersion = Assert-GodotVersion $verificationGodot
$consoleHash = Get-FileSha256 $verificationGodot
if ($provenance.engine.console_exe_sha256 -ne $consoleHash) {
    Stop-WithFailure ("Pinned console Godot binary hash mismatch (SHA-256 {0})." -f $consoleHash)
}
if ($Probe -or $HeadlessSmoke) {
    $godot = $verificationGodot
} else {
    $godot = Resolve-GodotExe $GodotExe -Windowed
    $windowedHash = Get-FileSha256 $godot
    if ($provenance.engine.exe_sha256 -ne $windowedHash) {
        Stop-WithFailure ("Pinned windowed Godot binary hash mismatch (SHA-256 {0})." -f $windowedHash)
    }
}

$metadata = [ordered]@{
    seed = $Seed
    rule_version = $ruleVersion
    engine_version = $engineVersion
    catalog_version = $catalogVersion
    supply_policy_version = $supplyPolicyVersion
    save_path = $savePath
    build_id = $buildIdentifier
}
Write-Host ("DESKTOP_PLAYTEST_REQUEST {0}" -f ($metadata | ConvertTo-Json -Compress))
Write-Host 'Same seed fixes the initial queue/checkpoint for matching versions; board-aware later supplies may diverge after board states differ.'

$launcherArguments = @('--path', $script:GameDir, '--script', 'res://tests/integration/desktop_playtest_launcher.gd', '--')
if ($Probe) {
    $launcherArguments += @('--probe', '--probe-root', $savePath, '--seed', $Seed, '--build-id', $buildIdentifier)
} else {
    $launcherArguments += @('--save-dir', $savePath, '--seed', $Seed, '--build-id', $buildIdentifier)
    if ($Condition -eq 'Auto') { $launcherArguments += '--auto' }
    if ($HeadlessSmoke) { $launcherArguments += '--smoke' }
}

if ($Probe -or $HeadlessSmoke) {
    $loggedArguments = @('--headless') + $launcherArguments
    $logName = 'desktop_playtest_' + $(if ($Probe) { 'probe' } else { 'smoke' })
    $exitCode = Invoke-GodotLogged $godot $loggedArguments $logName
    if ($exitCode -ne 0) {
        Stop-WithFailure ("Desktop playtest {0} exited with {1}." -f $logName, $exitCode)
    }
    $stdoutPath = Join-Path $script:OutDir ($logName + '.stdout.log')
    $stdoutText = Get-Content -LiteralPath $stdoutPath -Raw -Encoding UTF8
    $expectedMarker = if ($Probe) { 'DESKTOP_PLAYTEST_PROBE PASS' } else { 'DESKTOP_PLAYTEST_SMOKE PASS' }
    if ($stdoutText -notmatch [regex]::Escape($expectedMarker)) {
        Stop-WithFailure ("Expected success marker '{0}' was not found." -f $expectedMarker)
    }
    Write-Step ("{0} passed; metadata is stored in the new isolated save path." -f $logName)
    exit 0
}

$guiLogBase = Join-Path $script:OutDir ('desktop_playtest_gui_' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ'))
$guiStdout = $guiLogBase + '.stdout.log'
$guiStderr = $guiLogBase + '.stderr.log'
$quotedArguments = @($launcherArguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' })
$process = Start-Process -FilePath $godot -ArgumentList $quotedArguments -WindowStyle Normal -PassThru -RedirectStandardOutput $guiStdout -RedirectStandardError $guiStderr
Start-Sleep -Seconds 2
$process.Refresh()
if ($process.HasExited) {
    $errorText = if (Test-Path -LiteralPath $guiStderr) { Get-Content -LiteralPath $guiStderr -Raw } else { '' }
    Stop-WithFailure ("Godot exited before the playtest window was ready (code {0}); {1}" -f $process.ExitCode, $errorText.Trim())
}
$deadline = (Get-Date).AddSeconds(15)
$ready = $false
while ((Get-Date) -lt $deadline) {
    if (Test-Path -LiteralPath $guiStdout) {
        $ready = ((Get-Content -LiteralPath $guiStdout -Raw) -match 'DESKTOP_PLAYTEST_UI_READY')
        if ($ready) { break }
    }
    Start-Sleep -Milliseconds 250
}
if (-not $ready) {
    Stop-WithFailure ("Godot window remained running but AppRoot UI_READY was not observed within 15 seconds; logs: {0}, {1}" -f $guiStdout, $guiStderr)
}
Write-Step ("real AppRoot playtest window launched and UI_READY observed; logs: {0}; the new save is preserved at the printed path." -f $guiStdout)
