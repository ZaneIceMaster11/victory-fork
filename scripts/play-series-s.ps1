# Series S launcher. Boots and renders the prologue on an NVIDIA 12 GB card.
#
# Two Series S-specific fixes are needed on top of the normal set:
#   VICTORY_SKIP_BREAKPOINTS=1  steps over a title global-constructor int3 at
#                               boot (a checkpoint, not a fatal trap) that
#                               otherwise crashes before the first frame.
#   the upscaler patch          (built in, cherry-picked) makes the title keep
#                               its own upscaler instead of FSR 4, whose output
#                               never reaches the screen (every frame was black).
#                               VICTORY_TITLE_PATCHES=0 would turn it off.
#
#   scripts\play-series-s.ps1 [extra args...]

param([Parameter(ValueFromRemainingArguments=$true)] $Rest)

$game = "C:\GTA6\UnnamedGameTesting\game_scarlett_master.exe"

# --- Series S boot + render fixes ---
$env:VICTORY_SKIP_BREAKPOINTS    = "1"   # step over the boot int3

# --- Water correctness (boats float) ---
$env:VICTORY_TEXTURE_BACK        = "1"
$env:VICTORY_CARD_HASH_LEN       = "1"

# --- Display: cap at 1440p (no 4K) ---
$env:VICTORY_DISPLAY_MODE        = "2560x1440"

# --- Proven frame-rate set (shared with play-max) ---
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
$env:VICTORY_WIDE_TEXTURES       = "1"
$env:VICTORY_LIGHT_REFRESH       = "1"
$env:VICTORY_STEP_INDEX          = "1"
$env:VICTORY_FILLS_PLAIN         = "1"
$env:VICTORY_COPY_CHANGED        = "1"   # incremental refresh: only changed bytes to the card
$env:VICTORY_AMBIENT           = "0.6"   # non-black indirect light while ray tracing is off

$exe = Join-Path $PSScriptRoot "..\target\diag\victory.exe"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$log = Join-Path $PSScriptRoot "..\state\play-series-s-$stamp.log"
Write-Host "Logging this run to $log" -ForegroundColor Cyan
& $exe run $game --execute --console series-s @Rest *>&1 | Tee-Object -FilePath $log
& (Join-Path $PSScriptRoot "diag-summary.ps1") -DiagLog $log
