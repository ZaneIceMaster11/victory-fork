# Workspace test runner with logging. Uses --features victory-shader/host so
# the Agility SDK is staged for the SM 6.6 GPU tests (without it, ~23 shader
# tests fail with "no SM 6.6 device available"). Logs the full output to a
# timestamped file under state/ and prints a pass/fail summary with the names
# of any failing tests.
#
#   scripts\test.ps1 [-Runs N] [extra cargo-test args...]
#
#   -Runs N   Run the whole suite N times (default 1) to catch flaky tests.

param(
  [int]$Runs = 1,
  [Parameter(ValueFromRemainingArguments=$true)] $Rest
)

$ErrorActionPreference = "Continue"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$log   = Join-Path $PSScriptRoot "..\state\test-$stamp.log"
$anyFail = $false

for ($run = 1; $run -le $Runs; $run++) {
  Write-Host ("=== test run $run/$Runs ===") -ForegroundColor Cyan
  "===== run $run/$Runs @ $(Get-Date -Format o) =====" | Out-File -FilePath $log -Append -Encoding utf8

  $out = cargo test --workspace --features victory-shader/host @Rest 2>&1
  $out | Out-File -FilePath $log -Append -Encoding utf8

  $failingTests = $out | Select-String "^test .* \.\.\. FAILED$" | ForEach-Object { ($_ -replace '^test | \.\.\. FAILED$','').Trim() }
  $featErr      = @($out | Select-String "does not contain this feature").Count
  $resultLines  = $out | Select-String "test result:"
  $passed = 0; $failed = 0
  foreach ($r in $resultLines) {
    if ($r -match "(\d+) passed; (\d+) failed") { $passed += [int]$matches[1]; $failed += [int]$matches[2] }
  }

  if ($failingTests -or $featErr -gt 0 -or $failed -gt 0) {
    $anyFail = $true
    Write-Host ("  FAIL: $passed passed, $failed failed (featureErr=$featErr)") -ForegroundColor Red
    $failingTests | Sort-Object -Unique | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
  } else {
    Write-Host ("  OK: $passed passed, 0 failed") -ForegroundColor Green
  }
}

Write-Host ""
Write-Host ("Full log: $log")
if ($anyFail) { Write-Host "RESULT: failures seen - see log" -ForegroundColor Red; exit 1 }
else { Write-Host "RESULT: all green" -ForegroundColor Green; exit 0 }
