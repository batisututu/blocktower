# Blocktower tools: shared helpers for test.ps1 / run.ps1.
# 공통 도우미. 엔진 경로 해석, 버전 고정 검사, GUT 원본 매니페스트 해시 계산을 담당한다.
# PowerShell 5.1과 7 모두에서 동작해야 하므로 5.1 문법만 사용한다.

Set-StrictMode -Version 2.0

$script:RepoRoot = Split-Path -Parent $PSScriptRoot
$script:GameDir = Join-Path $script:RepoRoot 'game'
$script:ToolsDir = $PSScriptRoot
$script:OutDir = Join-Path $script:ToolsDir 'out'

function Write-Step([string]$Message) {
    Write-Host ("[blocktower] {0}" -f $Message)
}

function Stop-WithFailure([string]$Message) {
    Write-Host ("[FAIL] {0}" -f $Message) -ForegroundColor Red
    exit 1
}

# 엔진 실행 파일 결정 순서: -GodotExe 인자 > BLOCKTOWER_GODOT 환경 변수 > tools/engine.local.json
function Resolve-GodotExe([string]$Explicit, [switch]$Windowed) {
    if ($Explicit) {
        if (-not (Test-Path -LiteralPath $Explicit)) {
            Stop-WithFailure ("Godot executable not found: {0}" -f $Explicit)
        }
        return (Resolve-Path -LiteralPath $Explicit).Path
    }
    if ($env:BLOCKTOWER_GODOT) {
        if (-not (Test-Path -LiteralPath $env:BLOCKTOWER_GODOT)) {
            Stop-WithFailure ("BLOCKTOWER_GODOT does not exist: {0}" -f $env:BLOCKTOWER_GODOT)
        }
        return (Resolve-Path -LiteralPath $env:BLOCKTOWER_GODOT).Path
    }
    $localFile = Join-Path $script:ToolsDir 'engine.local.json'
    if (-not (Test-Path -LiteralPath $localFile)) {
        Stop-WithFailure ("No engine configured. Copy tools/engine.local.example.json to tools/engine.local.json, " +
            "or pass -GodotExe, or set BLOCKTOWER_GODOT.")
    }
    $local = Get-Content -LiteralPath $localFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $key = 'godot_console_exe'
    if ($Windowed) { $key = 'godot_exe' }
    # StrictMode에서 없는 속성 접근이 예외가 되지 않도록 속성 존재를 먼저 확인한다.
    $property = $local.PSObject.Properties[$key]
    $candidate = $null
    if ($property) { $candidate = $property.Value }
    if (-not $candidate) {
        Stop-WithFailure ("tools/engine.local.json has no '{0}' entry." -f $key)
    }
    if (-not (Test-Path -LiteralPath $candidate)) {
        Stop-WithFailure ("Configured engine path does not exist: {0}" -f $candidate)
    }
    return (Resolve-Path -LiteralPath $candidate).Path
}

# engine_version.txt 의 고정 문자열과 실제 --version 출력을 정확히 비교한다.
function Assert-GodotVersion([string]$GodotExe) {
    $pinFile = Join-Path $script:RepoRoot 'engine_version.txt'
    if (-not (Test-Path -LiteralPath $pinFile)) {
        Stop-WithFailure 'engine_version.txt is missing.'
    }
    $expected = (Get-Content -LiteralPath $pinFile -Raw -Encoding UTF8).Trim()
    $output = & $GodotExe --version
    $code = $LASTEXITCODE
    $actual = (($output | Out-String)).Trim()
    if ($code -ne 0) {
        Stop-WithFailure ("'{0} --version' exited with {1}." -f $GodotExe, $code)
    }
    if ($actual -ne $expected) {
        $message = "Engine version mismatch. expected '{0}' actual '{1}'. Use the pinned Godot build (see tools/engine_provenance.json)." -f $expected, $actual
        Stop-WithFailure $message
    }
    Write-Step ("engine version OK: {0}" -f $actual)
    return $actual
}

# Get-FileHash 대신 .NET을 직접 사용한다. 일부 환경에서 Windows PowerShell 5.1이 PowerShell 7의
# 모듈 경로를 먼저 읽어 Get-FileHash 자동 로드에 실패하는 문제를 피하기 위함이다.
function Get-FileSha256([string]$Path) {
    $full = (Resolve-Path -LiteralPath $Path).Path
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $stream = [System.IO.File]::OpenRead($full)
    try {
        $hash = $sha.ComputeHash($stream)
    } finally {
        $stream.Dispose()
        $sha.Dispose()
    }
    return (-join ($hash | ForEach-Object { $_.ToString('x2') }))
}

# GUT 원본 매니페스트 해시.
# 규칙: addons/gut 아래 모든 파일 중 *.import, *.uid 제외. 각 줄은 "<상대경로(/ 구분)> <sha256 소문자>".
# 줄을 바이트 순서(ordinal)로 정렬하고 "\n"으로 이어 붙인 뒤 마지막에 "\n"을 추가한 UTF-8 바이트의 SHA-256.
# bash 동치: cd addons/gut && find . -type f ! -name '*.import' ! -name '*.uid' | sed 's|^\./||' \
#   | LC_ALL=C sort | while read f; do printf '%s %s\n' "$f" "$(sha256sum "$f" | cut -d' ' -f1)"; done | sha256sum
function Get-GutManifestHash([string]$GutDir) {
    $root = (Resolve-Path -LiteralPath $GutDir).Path.TrimEnd('\', '/')
    $files = Get-ChildItem -LiteralPath $root -Recurse -File |
        Where-Object { $_.Extension -ne '.import' -and $_.Extension -ne '.uid' }
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($file in $files) {
        $relative = $file.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
        $lines.Add(("{0} {1}" -f $relative, (Get-FileSha256 $file.FullName)))
    }
    $array = $lines.ToArray()
    [System.Array]::Sort($array, [System.StringComparer]::Ordinal)
    $text = ($array -join "`n") + "`n"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash($bytes)
    } finally {
        $sha.Dispose()
    }
    $hex = -join ($hash | ForEach-Object { $_.ToString('x2') })
    return @{ hash = $hex; file_count = $array.Length }
}

# JUnit XML 속성을 정수로 읽는다. 속성이 없거나 비어 있으면 0으로 본다(예외 대신).
function Get-IntAttribute($Node, [string]$Name) {
    if ($null -eq $Node -or -not $Node.HasAttribute($Name)) { return 0 }
    $raw = $Node.GetAttribute($Name)
    $value = 0
    if ([int]::TryParse($raw, [ref]$value)) { return $value }
    return 0
}

function Read-GutPluginVersion([string]$GutDir) {
    $cfg = Join-Path $GutDir 'plugin.cfg'
    if (-not (Test-Path -LiteralPath $cfg)) { return $null }
    foreach ($line in Get-Content -LiteralPath $cfg -Encoding UTF8) {
        if ($line -match '^\s*version\s*=\s*"([^"]+)"') { return $Matches[1] }
    }
    return $null
}

function Read-Provenance {
    $file = Join-Path $script:ToolsDir 'engine_provenance.json'
    if (-not (Test-Path -LiteralPath $file)) {
        Stop-WithFailure 'tools/engine_provenance.json is missing.'
    }
    return (Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json)
}

# Godot는 일부 파서 오류에도 0을 반환하므로 로그와 종료 코드를 함께 검사한다.
function Invoke-GodotLogged([string]$Executable, [string[]]$Arguments, [string]$LogName) {
    $stdout = Join-Path $script:OutDir ($LogName + '.stdout.log')
    $stderr = Join-Path $script:OutDir ($LogName + '.stderr.log')
    $quoted = @($Arguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' })
    $process = Start-Process -FilePath $Executable -ArgumentList $quoted -WindowStyle Hidden -PassThru -Wait -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $log = (Get-Content -LiteralPath $stdout -Raw) + "`n" + (Get-Content -LiteralPath $stderr -Raw)
    Write-Host $log
    if ($log -match '(?m)(SCRIPT ERROR:|Parse Error:|^\s*ERROR:)') {
        Stop-WithFailure ("{0} contains engine errors; see tools/out/{0}.*.log." -f $LogName)
    }
    return $process.ExitCode
}
