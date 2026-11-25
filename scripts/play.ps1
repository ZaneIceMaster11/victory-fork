# Launch the title with the frame-rate switches enabled (off by default in the
# engine so they can be A/B'd). Measured on an RTX 3060 / i7-14700KF: holds the
# 30 fps cap in the prologue where defaults stuttered (copy-back moved off the
# frame thread onto the GPU copy queue via VICTORY_QUEUE2).
#
#   scripts\play.ps1 [-ConsoleS] [extra victory.exe args...]
#
# Prereqs (run once): `cargo xtask agility-sdk`, then build:
#   cargo build --profile diag -p victory --features diagnostics
# and warm the shader cache for smooth first visits:
#   $env:VICTORY_HOST_WAVE=32; $env:VICTORY_VIEW_LIMIT=1000000
#   target\diag\victory.exe translate --warm all "C:\GTA6\UnnamedGameTesting"

param([switch]$ConsoleS, [Parameter(ValueFromRemainingArguments=$true)] $Rest)

$game = "C:\GTA6\UnnamedGameTesting\game_scarlett_master.exe"
$console = if ($ConsoleS) { "series-s" } else { "series-x" }

# Readback / submit offload to the GPU copy queue and extra threads (origin's
# README frame-rate set + the async switches that passed a clean run here).
$env:VICTORY_RELAY               = "2"    # a thread of our own copies shader writes back
$env:VICTORY_QUEUE2              = "1"    # those fetches go to a GPU copy queue (off the frame thread)
$env:VICTORY_ASYNC_SUBMIT        = "1"    # a submit thread of the layer's own
$env:VICTORY_LATE_WAIT           = "3"    # wait for shader writes as late as safe
$env:VICTORY_WIDE_BACK           = "1"    # wider copy-back
$env:VICTORY_CARD_BUFFERS_MIN_MB = "1"    # the card (GPU) compares buffers >= 1 MiB
$env:VICTORY_CARD_BUFFERS_MB     = "1024" # up to 1 GiB of card compare buffers
$env:VICTORY_CARD_FETCH_INFLIGHT = "1"    # card fetches run inside their flights

$exe = Join-Path $PSScriptRoot "..\target\diag\victory.exe"
& $exe run $game --execute --console $console @Rest
