# Capture the actual Godot review scene at explicit logical viewport sizes.
[CmdletBinding()]
param([string]$GodotExe, [string]$OutputDirectory = 'docs/design/captures')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
$godot = Resolve-GodotExe $GodotExe
Assert-GodotVersion $godot | Out-Null
$captureRoot = [System.IO.Path]::GetFullPath((Join-Path $script:RepoRoot $OutputDirectory))
New-Item -ItemType Directory -Path $captureRoot -Force | Out-Null
$cases = @(
    @{name='basic_360x800';size='360x800';state='basic'},
    @{name='basic_320x568';size='320x568';state='basic'},
    @{name='ready_360x800';size='360x800';state='ready'},
    @{name='cross_412x915';size='412x915';state='cross'},
    @{name='valid_360x800';size='360x800';state='valid'},
    @{name='invalid_360x800';size='360x800';state='invalid'},
    @{name='blocked_360x800';size='360x800';state='blocked'},
    @{name='game_over_320x568';size='320x568';state='game_over'},
    @{name='save_error_360x800';size='360x800';state='save_error'},
    @{name='auto_confirm_320x568';size='320x568';state='cross';confirm=$true},
    @{name='tower_13_360x800';size='360x800';screen='tower';floors=13},
    @{name='tower_0_320x568';size='320x568';screen='tower';floors=0},
    @{name='tower_30_412x915';size='412x915';screen='tower';floors=30}
)
$records = @()
foreach ($case in $cases) {
    $outputPath = Join-Path $captureRoot ($case.name + '.png')
    $stdout = Join-Path $captureRoot ($case.name + '.stdout.log')
    $stderr = Join-Path $captureRoot ($case.name + '.stderr.log')
    $arguments = @('--path', $script:GameDir, 'res://scenes/main.tscn', '--resolution', $case.size, '--', ('--review-size='+$case.size), ('--capture='+$outputPath))
    if ($case['state']) { $arguments += '--state='+$case['state'] }
    if ($case['screen']) { $arguments += '--screen='+$case['screen']; $arguments += '--floors='+$case['floors'] }
    if ($case['confirm']) { $arguments += '--auto-confirm' }
    $quotedArguments = @($arguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' })
    $process = Start-Process -FilePath $godot -ArgumentList $quotedArguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    if (-not $process.WaitForExit(20000)) { throw ('Capture timed out: '+$case.name+' PID '+$process.Id) }
    $process.Refresh()
    $outputText = Get-Content -LiteralPath $stdout -Raw
    $errorText = Get-Content -LiteralPath $stderr -Raw
    if ($process.ExitCode -ne 0 -or $errorText -match 'ERROR|Parse Error' -or $outputText -notmatch 'DESIGN_CAPTURE.*result=0' -or -not (Test-Path -LiteralPath $outputPath)) { throw ('Capture failed: '+$case.name+' '+$errorText) }
    $records += @{name=$case.name;size=$case.size;file=($case.name+'.png');sha256=(Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash.ToLower();exit_code=$process.ExitCode}
    Write-Host ('Captured '+$case.name)
}
@{date=(Get-Date).ToString('s');source='Godot desktop OpenGL viewport; not Android device evidence';captures=$records} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $captureRoot 'capture_manifest.json') -Encoding utf8

