# Shared post-run diagnostic summary. Dot-sourced by the play launchers with
# $DiagLog set to the run's log path. Prints frame-time good/bad, dropped
# shaders, ray-tracing state, memory growth, and the crash reason if any.
param([string]$DiagLog)

function _T($s,$n){ $s="$s"; if($s.Length -gt $n){$s.Substring(0,$n)}else{$s} }
$lines = ((Get-Content $DiagLog -Raw -ErrorAction SilentlyContinue) -replace '\x1b\[[0-9;]*m','') -split "`r?`n"

Write-Host ""
Write-Host "==== diagnostic summary ====" -ForegroundColor Green

# Frame time: distribution + good/bad split (>=10 fps good, <5 fps bad)
$fps = $lines | Select-String "(\d+\.\d+) fps" | ForEach-Object { if($_ -match '(\d+\.\d+) fps'){[double]$matches[1]} }
if ($fps) {
  $good = @($fps | Where-Object { $_ -ge 10 }).Count
  $bad  = @($fps | Where-Object { $_ -lt 5 }).Count
  $st = $fps | Measure-Object -Average -Minimum -Maximum
  Write-Host ("frame rate : avg {0:N1} fps (min {1} max {2}); {3} samples >=10fps (good), {4} <5fps (bad)" -f $st.Average,$st.Minimum,$st.Maximum,$good,$bad)
  # Dominant cost in the worst frames
  $worst = $lines | Select-String "fps, [0-9.]+ ms/frame" | ForEach-Object { if($_ -match '\(([0-9.]+) preparing: copies ([0-9.]+) ms [0-9.]+ MB, textures ([0-9.]+) ms [0-9.]+ MB; ([0-9.]+) on the GPU'){[pscustomobject]@{prep=[double]$matches[1];copies=[double]$matches[2];tex=[double]$matches[3];gpu=[double]$matches[4]}} } | Sort-Object { $_.prep + $_.gpu } -Descending | Select-Object -First 1
  if ($worst) { Write-Host ("worst frame: prep {0} ms (copies {1}, textures {2}), GPU {3} ms -> {4}" -f $worst.prep,$worst.copies,$worst.tex,$worst.gpu, $(if($worst.gpu -gt $worst.prep){"GPU-bound"}else{"CPU/prep-bound"})) }
}

# Shader pipelines: dropped draws by reason
Write-Host "dropped shaders (missing geometry):"
$lines | Select-String "dropped [0-9.]+/frame without a host pipeline" | Select-Object -Last 4 | ForEach-Object { Write-Host ("   " + (_T $_.ToString().Trim() 150)) }

# Ray tracing
$rt = $lines | Select-String "ray-tracing structure builder|builder, which is off|not built" | Select-Object -Last 1
if ($rt) { Write-Host ("ray tracing : " + (_T $rt.ToString().Trim() 150)) }

# Memory growth (OOM watch)
$mem = $lines | Select-String "(\d+) MB private" | ForEach-Object { if($_ -match '(\d+) MB private'){[int]$matches[1]} }
if ($mem) { Write-Host ("memory     : {0} -> {1} MB private (grew {2} MB) - OOM device loss near ~24000 MB" -f $mem[0],$mem[-1],($mem[-1]-$mem[0])) }

# Crash
$crash = $lines | Select-String "device removed:|unhandled exception 0x|memory when the host device went" | Select-Object -First 2
if ($crash) { Write-Host "CRASH:" -ForegroundColor Red; $crash | ForEach-Object { Write-Host ("   " + (_T $_.ToString().Trim() 180)) -ForegroundColor Red } }
else { Write-Host "no crash in the log" -ForegroundColor Green }

Write-Host ("full log: $DiagLog")
