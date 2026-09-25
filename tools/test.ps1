# Blocktower W1 test runner.
# 순서: 엔진 경로 해석 -> 버전 고정 검사 -> 엔진/GUT 고정 해시 검사 -> 헤드리스 import -> GUT 단위 테스트
#       -> JUnit XML 검증(테스트 0개, 실패, 오류, pending 모두 실패 처리) -> tools/out 에 요약 기록.
# 사용: powershell -NoProfile -ExecutionPolicy Bypass -File tools/test.ps1 [-GodotExe <path>] [-SkipImport]
#       [-AllowPending] [-AllowUnpinnedEngine] [-TestDir res://tests/unit] [-PrintGutHash]

[CmdletBinding()]
param(
    [string]$GodotExe,
    [switch]$SkipImport,
    [switch]$AllowPending,
    [switch]$AllowUnpinnedEngine,
    [string]$TestDir = 'res://tests/unit',
    [switch]$PrintGutHash
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

$gutDir = Join-Path $script:GameDir 'addons\gut'

if ($PrintGutHash) {
    $manifest = Get-GutManifestHash $gutDir
    Write-Output ("{0} {1}" -f $manifest.hash, $manifest.file_count)
    exit 0
}

if (-not (Test-Path -LiteralPath (Join-Path $script:GameDir 'project.godot'))) {
    Stop-WithFailure 'game/project.godot not found.'
}
New-Item -ItemType Directory -Force -Path $script:OutDir | Out-Null

# 1. 엔진과 버전
$godot = Resolve-GodotExe $GodotExe
Write-Step ("engine: {0}" -f $godot)
$version = Assert-GodotVersion $godot

# 2. 고정 해시 (엔진 실행 파일, GUT 원본)
$provenance = Read-Provenance
$engineHash = Get-FileSha256 $godot
$pinnedHashes = @($provenance.engine.console_exe_sha256, $provenance.engine.exe_sha256)
if ($pinnedHashes -contains $engineHash) {
    Write-Step ("engine binary hash OK: {0}" -f $engineHash)
} elseif ($AllowUnpinnedEngine) {
    Write-Warning ("engine binary hash {0} is not the pinned build; continuing because -AllowUnpinnedEngine was given." -f $engineHash)
} else {
    Stop-WithFailure ("engine binary hash {0} does not match tools/engine_provenance.json. " -f $engineHash +
        "Pass -AllowUnpinnedEngine only for a deliberate experiment.")
}

$gutVersion = Read-GutPluginVersion $gutDir
if ($gutVersion -ne $provenance.gut.version) {
    Stop-WithFailure ("GUT plugin.cfg version '{0}' != pinned '{1}'." -f $gutVersion, $provenance.gut.version)
}
$manifest = Get-GutManifestHash $gutDir
if ($manifest.hash -ne $provenance.gut.source_manifest_sha256) {
    Stop-WithFailure ("GUT source manifest hash {0} ({1} files) != pinned {2}. addons/gut was modified or is not commit {3}." -f
        $manifest.hash, $manifest.file_count, $provenance.gut.source_manifest_sha256, $provenance.gut.commit)
}
Write-Step ("GUT {0} pinned OK ({1} source files, commit {2})" -f $gutVersion, $manifest.file_count, $provenance.gut.commit)

# 3. 헤드리스 import (종료 코드가 0이어도 파서 오류 로그는 실패 처리)
if (-not $SkipImport) {
    Write-Step 'headless import'
    $importExit = Invoke-GodotLogged $godot @('--headless', '--path', $script:GameDir, '--editor', '--import') 'import'
    if ($importExit -ne 0) {
        Stop-WithFailure ("Godot import failed with exit code {0}." -f $importExit)
    }
}

# 4. GUT 실행 (JUnit XML을 남겨 결과를 파일로 판정한다)
$junitPath = (Join-Path $script:OutDir 'gut_unit.xml')
if (Test-Path -LiteralPath $junitPath) { Remove-Item -LiteralPath $junitPath -Force }
$junitArg = '-gjunit_xml_file=' + $junitPath.Replace('\', '/')
Write-Step ("GUT run: {0}" -f $TestDir)
$gutExit = Invoke-GodotLogged $godot @('--headless', '--path', $script:GameDir, '-s', 'addons/gut/gut_cmdln.gd', ("-gdir=" + $TestDir), '-ginclude_subdirs', '-gexit', $junitArg) 'gut'

if (-not (Test-Path -LiteralPath $junitPath)) {
    Stop-WithFailure ("GUT did not write {0} (exit code {1}). Treating as failure." -f $junitPath, $gutExit)
}
[xml]$doc = Get-Content -LiteralPath $junitPath -Raw -Encoding UTF8
$suites = @($doc.SelectNodes('//testsuite'))
$tests = 0; $failures = 0; $errors = 0; $skipped = 0
foreach ($suite in $suites) {
    $tests += Get-IntAttribute $suite 'tests'
    $failures += Get-IntAttribute $suite 'failures'
    $errors += Get-IntAttribute $suite 'errors'
    $skipped += Get-IntAttribute $suite 'skipped'
}
# 요약 속성과 별개로 testcase 단위의 failure/error/skipped 노드도 센다(요약 누락 대비).
$caseCount = @($doc.SelectNodes('//testcase')).Count
$caseFailures = @($doc.SelectNodes('//testcase/failure')).Count
$caseErrors = @($doc.SelectNodes('//testcase/error')).Count
$caseSkipped = @($doc.SelectNodes('//testcase/skipped')).Count
if ($caseCount -gt $tests) { $tests = $caseCount }
if ($caseFailures -gt $failures) { $failures = $caseFailures }
if ($caseErrors -gt $errors) { $errors = $caseErrors }
if ($caseSkipped -gt $skipped) { $skipped = $caseSkipped }

$summary = [ordered]@{
    date = (Get-Date).ToString('s')
    engine_version = $version
    engine_exe = $godot
    engine_sha256 = $engineHash
    gut_version = $gutVersion
    gut_source_manifest_sha256 = $manifest.hash
    test_dir = $TestDir
    suites = $suites.Count
    tests = $tests
    failures = $failures
    errors = $errors
    pending = $skipped
    gut_exit_code = $gutExit
    junit_xml = $junitPath
}
$summary | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $script:OutDir 'last_test_run.json') -Encoding UTF8
Write-Step ("GUT result: suites={0} tests={1} failures={2} errors={3} pending={4} exit={5}" -f
    $suites.Count, $tests, $failures, $errors, $skipped, $gutExit)

if ($tests -le 0) { Stop-WithFailure 'zero tests were discovered; a run without tests is not a pass.' }
if ($failures -gt 0 -or $errors -gt 0) { Stop-WithFailure ("{0} failure(s), {1} error(s)." -f $failures, $errors) }
if ($skipped -gt 0 -and -not $AllowPending) { Stop-WithFailure ("{0} pending/skipped test(s); pass -AllowPending only for a documented reason." -f $skipped) }
if ($gutExit -ne 0) { Stop-WithFailure ("GUT exited with {0}." -f $gutExit) }

Write-Host '[PASS] W1 test run complete.' -ForegroundColor Green
exit 0
