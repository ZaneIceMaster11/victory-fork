# Crash-fix validation launch: runs the title with the frame-rate switches,
# captures the full log to a timestamped file, and on exit prints whether the
# R9G9B9E5 (format 67) stand-in engaged and whether the card was ever lost.
#
# Play into the heavy scene that previously dropped the card (the one that
# crashed ~1 min in). If it no longer crashes, the format-67 fix holds.
#
#   scripts\validate.ps1 [-ConsoleS] [-DebugLayer] [extra args...]
#
#   -DebugLayer  Turn on the D3D12 debug layer + DRED so that IF it still
#                drops, the log names the exact invalid call. Slower - only
#                use it if a plain run still crashes and you need the cause.

param(
  [switch]$ConsoleS,
  [switch]$DebugLayer,
  [Parameter(ValueFromRemainingArguments=$true)] $Rest
)

$game    = "C:\GTA6\UnnamedGameTesting\game_scarlett_master.exe"
$console = if ($ConsoleS) { "series-s" } else { "series-x" }
$exe     = Join-Path $PSScriptRoot "..\target\diag\victory.exe"
$stamp   = Get-Date -Format "yyyyMMdd-HHmmss"
$log     = Join-Path $PSScriptRoot "..\state\validate-$console-$stamp.log"

# Frame-rate switches (same as play-max.ps1, the aggressive set):
$env:VICTORY_RELAY               = "2"
$env:VICTORY_QUEUE2              = "1"
$env:VICTORY_ASYNC_SUBMIT        = "1"
$env:VICTORY_ASYNC_PRESENT       = "1"
$env:VICTORY_CARD_FETCH_INFLIGHT = "1"
$env:VICTORY_LATE_WAIT           = "3"
$env:VICTORY_WIDE_BACK           = "1"
$env:VICTORY_CARD_BUFFERS_MIN_MB = "1"
$env:VICTORY_CARD_BUFFERS_MB     = "1024"
$env:VICTORY_CARD_REHASH_RUNS    = "1"
$env:VICTORY_MERGE_GAP           = "64"
$env:VICTORY_MERGE_RUNS          = "4096"
$env:VICTORY_INDIRECT_GATHER     = "1"
$env:VICTORY_TEXTURE_NO_WAIT     = "1"
$env:VICTORY_LEVELS_ON_DEMAND    = "1"

if ($DebugLayer) {
  # Names the invalid call if the device is still removed (diagnostics build).
  $env:VICTORY_D3D12_DEBUG = "1"
  $env:VICTORY_D3D12_DRED  = "1"
  Write-Host "D3D12 debug layer + DRED ON (slower; only for catching a crash)" -ForegroundColor Yellow
}

Write-Host "Logging to $log" -ForegroundColor Cyan
Write-Host "Play into the scene that previously dropped the card, then quit." -ForegroundColor Cyan

& $exe run $game --execute --console $console @Rest *>&1 | Tee-Object -FilePath $log

# Post-run summary (strip ANSI, scan for the telltale lines).
$lines = (Get-Content $log -Raw -ErrorAction SilentlyContinue) -split "`r?`n" |
         ForEach-Object { $_ -replace '\x1b\[[0-9;]*m','' }

$standIn67 = @($lines | Select-String -Pattern "does not render to this format.*format=67|format = 67").Count
$fail67     = @($lines | Select-String -Pattern "no host texture.*format: 67").Count
$removed    = @($lines | Select-String -Pattern "887A0005|device removed").Count
$reason     = $lines | Select-String -Pattern "device removed:" | Select-Object -First 1
$worst      = $lines | Select-String -Pattern "\d+\.\d+ fps, [0-9.]+ ms/frame" |
              ForEach-Object { if ($_ -match '(\d+\.\d+) fps, ([0-9.]+) ms') { [double]$matches[2] } } |
              Sort-Object -Descending | Select-Object -First 1

Write-Host ""
Write-Host "==== validation summary ====" -ForegroundColor Green
Write-Host ("format-67 stand-in engaged : {0}  (want >= 1 if the scene used R9G9B9E5 targets)" -f $standIn67)
Write-Host ("format-67 create failures  : {0}  (want 0)" -f $fail67)
Write-Host ("device-removed events      : {0}  (want 0 -> fix held)" -f $removed)
if ($reason) { Write-Host ("removed reason             : {0}" -f ($reason.ToString().Trim())) -ForegroundColor Red }
if ($worst)  { Write-Host ("worst frame time           : {0} ms" -f $worst) }
Write-Host "Full log: $log"
