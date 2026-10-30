$ErrorActionPreference = "Stop"
$src   = "C:\Users\win11\jarvis"
$stamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$log   = "C:\Users\win11\jarvis\tools\backup.log"

# Куда сохранять: Google Диск (любая буква) -> OneDrive -> локально
$dest = $null
foreach ($drv in (Get-PSDrive -PSProvider FileSystem)) {
  foreach ($n in @("Мой диск", "My Drive")) {
    $d = Join-Path $drv.Root $n
    if (-not $dest -and (Test-Path $d)) { $dest = Join-Path $d "Jarvis-backup" }
  }
}
if (-not $dest -and $env:OneDrive) { $dest = Join-Path $env:OneDrive "Jarvis-backup" }
if (-not $dest) { $dest = "C:\Users\win11\Jarvis-backup" }
New-Item -ItemType Directory -Force -Path $dest | Out-Null

$tmp    = Join-Path $env:TEMP "jarvis-backup-$stamp"
$tmpZip = Join-Path $env:TEMP "jarvis_$stamp.zip"
try {
  # 1. Папка Джарвиса без тяжёлого и временного
  robocopy $src "$tmp\jarvis" /E /XD .voice whisper-env node_modules .git /XF *.mp3 *.ogg *.oga *.log /R:1 /W:1 /NFL /NDL /NJH /NJS | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "robocopy error $LASTEXITCODE" }

  # 2. Глобальные настройки Claude Code (без секретов)
  $u = "$tmp\user-claude"; New-Item -ItemType Directory -Force -Path $u | Out-Null
  foreach ($f in @("settings.json", "keybindings.json", "CLAUDE.md")) {
    $p = Join-Path $HOME ".claude\$f"; if (Test-Path $p) { Copy-Item $p $u }
  }

  # 3. Список MCP-серверов
  Push-Location $src
  try { claude mcp list 2>&1 | Out-File "$tmp\mcp-list.txt" -Encoding utf8 } catch {}
  Pop-Location

  # 4. Архив во ВРЕМЕННОЙ папке на компьютере
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  [IO.Compression.ZipFile]::CreateFromDirectory($tmp, $tmpZip)

  # 5. Проверка, что архив целый
  $z = [IO.Compression.ZipFile]::OpenRead($tmpZip); $count = $z.Entries.Count; $z.Dispose()
  if ($count -lt 5) { throw "в архиве слишком мало файлов: $count" }

  # 6. Копируем готовый архив в облако
  Copy-Item $tmpZip (Join-Path $dest "jarvis_$stamp.zip") -Force

  # 7. Храним только 8 последних копий
  Get-ChildItem $dest -Filter "jarvis_*.zip" | Sort-Object LastWriteTime -Descending | Select-Object -Skip 8 | Remove-Item -Force

  $size = [math]::Round((Get-Item $tmpZip).Length / 1MB, 1)
  Add-Content $log "$(Get-Date -Format s)  OK  $dest\jarvis_$stamp.zip  ($count файлов, $size MB)"
} catch {
  Add-Content $log "$(Get-Date -Format s)  ERROR  $_"
} finally {
  if (Test-Path $tmp)    { Remove-Item $tmp -Recurse -Force }
  if (Test-Path $tmpZip) { Remove-Item $tmpZip -Force }
}