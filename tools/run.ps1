# Blocktower launcher using the pinned Godot build.
# 사용: powershell -NoProfile -ExecutionPolicy Bypass -File tools/run.ps1 [-Editor] [-Windowed] [-GodotExe <path>]
#   기본: game/ 프로젝트의 메인 씬(res://scenes/app.tscn)을 실행한다. 씬이 아직 없으면 실행하지 않고 안내한다.
#   -Editor: 에디터를 연다. -Windowed: 콘솔 창 없는 실행 파일(godot_exe)을 사용한다.

[CmdletBinding()]
param(
    [string]$GodotExe,
    [switch]$Editor,
    [switch]$Windowed
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

if (-not (Test-Path -LiteralPath (Join-Path $script:GameDir 'project.godot'))) {
    Stop-WithFailure 'game/project.godot not found.'
}

$godot = Resolve-GodotExe $GodotExe -Windowed:$Windowed
Assert-GodotVersion $godot | Out-Null

if ($Editor) {
    Write-Step 'opening editor'
    & $godot --path $script:GameDir --editor
    exit $LASTEXITCODE
}

$mainScene = Join-Path $script:GameDir 'scenes\app.tscn'
if (-not (Test-Path -LiteralPath $mainScene)) {
    Stop-WithFailure 'game/scenes/app.tscn is missing. Restore the W3 application entry scene.'
}

Write-Step 'running main scene'
& $godot --path $script:GameDir
exit $LASTEXITCODE
