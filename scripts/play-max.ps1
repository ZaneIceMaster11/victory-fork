# Play with the switch set that is proven on a 12 GB NVIDIA card (fxceless's
# run 279/280 on an RTX 4070 12 GB, close to this RTX 3060 12 GB): 9-12 fps in
# rooms/light outdoor, water right and boats float. Centers on
# VICTORY_TEXTURE_BACK=1 (the ocean's height/displacement maps copied back so
# the title's CPU buoyancy code reads them - without it boats sink and the
# boat mission fails) and VICTORY_CARD_HASH_LEN=1 (the water is lit correctly).
# Plus the verified-stable perf switches from our own merges.
#
# Deliberately NOT set: VICTORY_REMAP_LEAN/REMAP_BATCH (crash this title at
# load with a null write) and VICTORY_SHADER_OPT=127 (blackens the water).
#
#   scripts\play-max.ps1 [-ConsoleS] [extra args...]

param([switch]$ConsoleS, [Parameter(ValueFromRemainingArguments=$true)] $Rest)

$game = "C:\GTA6\UnnamedGameTesting\game_scarlett_master.exe"
$console = if ($ConsoleS) { "series-s" } else { "series-x" }

# --- Water correctness (the boat fix) ---
$env:VICTORY_TEXTURE_BACK        = "1"   # ocean height/displacement maps read back to title memory
$env:VICTORY_CARD_HASH_LEN       = "1"   # the water is lit right (blue, waves, sun path)

# --- fxceless's proven frame-rate set (run 279/280) ---
$env:VICTORY_LEVELS_ON_DEMAND    = "1"
$env:VICTORY_ASYNC_SUBMIT        = "1"
$env:VICTORY_QUEUE2              = "1"
$env:VICTORY_INDIRECT_WINDOW     = "1"
$env:VICTORY_TEXTURE_NO_WAIT     = "1"
$env:VICTORY_MERGE_GAP           = "64"
$env:VICTORY_MERGE_RUNS          = "4096"
$env:VICTORY_STAGING_POOL        = "0"
$env:VICTORY_COPY_PLAIN          = "1"
$env:VICTORY_JOIN_PARTS          = "1"
$env:VICTORY_BACK_OWN_VIEW       = "1"
$env:VICTORY_INDIRECT_GATHER     = "1"
$env:VICTORY_CARD_REHASH_RUNS    = "1"
$env:VICTORY_CARD_WINDOWS_MB     = "2048"
$env:VICTORY_CARD_BUFFERS_MIN_KB = "64"
$env:VICTORY_CARD_BUFFERS_MB     = "1280"

# --- Our own verified-stable perf additions ---
$env:VICTORY_WIDE_TEXTURES       = "1"   # detile a submission's textures across cores
$env:VICTORY_LIGHT_REFRESH       = "1"   # lock-free host-copy refresh
$env:VICTORY_STEP_INDEX          = "1"   # a submission's steps found by index
$env:VICTORY_FILLS_PLAIN         = "1"   # small fills copied in place
$env:VICTORY_COPY_CHANGED        = "1"   # incremental refresh: send only the changed bytes to the card (81->4-21 MB/frame)

$exe = Join-Path $PSScriptRoot "..\target\diag\victory.exe"
& $exe run $game --execute --console $console @Rest
