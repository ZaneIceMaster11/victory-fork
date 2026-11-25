# Max-FPS variant of play.ps1: the full aggressive switch matrix from origin's
# README, aimed at heavy in-game scenes (where copy-back and texture streaming
# dominate and the GPU sits idle). More experimental than play.ps1 - if a scene
# corrupts or hangs, fall back to play.ps1 and report which scene.
#
#   scripts\play-max.ps1 [-ConsoleS] [extra args...]

param([switch]$ConsoleS, [Parameter(ValueFromRemainingArguments=$true)] $Rest)

$game = "C:\GTA6\UnnamedGameTesting\game_scarlett_master.exe"
$console = if ($ConsoleS) { "series-s" } else { "series-x" }

# Readback / submit / present offload (async, GPU copy queue):
$env:VICTORY_RELAY               = "2"
$env:VICTORY_QUEUE2              = "1"
$env:VICTORY_ASYNC_SUBMIT        = "1"
$env:VICTORY_ASYNC_PRESENT       = "1"
$env:VICTORY_CARD_FETCH_INFLIGHT = "1"
# Readback timing / width:
$env:VICTORY_LATE_WAIT           = "3"
$env:VICTORY_WIDE_BACK           = "1"
# Buffer change-detection on the GPU, not the CPU:
$env:VICTORY_CARD_BUFFERS_MIN_MB = "1"
$env:VICTORY_CARD_BUFFERS_MB     = "1024"
$env:VICTORY_CARD_REHASH_RUNS    = "1"
# Shader-write range merging (fewer, larger copy-backs):
$env:VICTORY_MERGE_GAP           = "64"
$env:VICTORY_MERGE_RUNS          = "4096"
# Indirect-draw clamping once per list instead of per record:
$env:VICTORY_INDIRECT_GATHER     = "1"
# Textures: don't block the frame on a refresh; stream mip levels on demand:
$env:VICTORY_TEXTURE_NO_WAIT     = "1"
$env:VICTORY_LEVELS_ON_DEMAND    = "1"

$exe = Join-Path $PSScriptRoot "..\target\diag\victory.exe"
& $exe run $game --execute --console $console @Rest
