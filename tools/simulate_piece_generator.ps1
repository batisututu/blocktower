[CmdletBinding()]
param([ValidateRange(10,1000000)][int]$SampleCount = 100000, [string]$GodotExe)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
New-Item -ItemType Directory -Force -Path $script:OutDir | Out-Null
$godot = Resolve-GodotExe $GodotExe
$version = Assert-GodotVersion $godot
$provenance = Read-Provenance
$hash = Get-FileSha256 $godot
if (@($provenance.engine.console_exe_sha256, $provenance.engine.exe_sha256) -notcontains $hash) {
    Stop-WithFailure 'Simulation requires the pinned engine binary.'
}
$output = Join-Path $script:OutDir 'piece_generation_simulation.json'
if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output }
$code = Invoke-GodotLogged $godot @('--headless', '--path', $script:GameDir, '-s', 'res://tests/simulation/piece_generator_simulation.gd', '--', "$SampleCount", $output.Replace('\','/')) 'piece_simulation'
if ($code -ne 0 -or -not (Test-Path -LiteralPath $output)) { Stop-WithFailure 'Simulation failed or report missing.' }
$report = Get-Content -LiteralPath $output -Raw -Encoding UTF8 | ConvertFrom-Json
if ($report.ok -ne $true -or @($report.policies).Count -ne 3) { Stop-WithFailure 'Invalid simulation result.' }
foreach ($policy in $report.policies) {
    if ($policy.trays -ne $SampleCount) { Stop-WithFailure 'Incomplete simulation sample.' }
}
Write-Host "[PASS] $($SampleCount * 3) trays verified on $version"
