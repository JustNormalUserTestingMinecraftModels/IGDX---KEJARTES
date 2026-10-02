<#
.SYNOPSIS
    Self-test for shrink_web.ps1 on a fake export folder. Prints PASS/FAIL lines;
    exits 1 if any check fails.
#>
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem
$script = Join-Path $PSScriptRoot "shrink_web.ps1"
$root = Join-Path ([IO.Path]::GetTempPath()) ("shrinkweb_" + [guid]::NewGuid().ToString("N"))
$dir = Join-Path $root "web"
New-Item -ItemType Directory -Force $dir | Out-Null
$fails = 0
function Check([bool]$ok, [string]$what) {
    if ($ok) { Write-Host "PASS $what" } else { Write-Host "FAIL $what" -ForegroundColor Red; $script:fails++ }
}
function Gunzip-Length([string]$p) {
    $in = [IO.File]::OpenRead($p); $ms = New-Object IO.MemoryStream
    try {
        $gz = New-Object IO.Compression.GZipStream($in, [IO.Compression.CompressionMode]::Decompress)
        $gz.CopyTo($ms); $gz.Dispose()
    } finally { $in.Dispose() }
    return $ms.Length
}

[IO.File]::WriteAllText((Join-Path $dir "index.html"), "<html></html>")
$pck = New-Object byte[] 3000000
for ($i = 0; $i -lt $pck.Length; $i += 97) { $pck[$i] = [byte]($i % 251) }
[IO.File]::WriteAllBytes((Join-Path $dir "index.pck"), $pck)
[IO.File]::WriteAllText((Join-Path $dir "index.js"), ("var a = 1;`n" * 5000))
$wasm = New-Object byte[] 100000
for ($i = 0; $i -lt $wasm.Length; $i += 13) { $wasm[$i] = [byte]($i % 7) }
[IO.File]::WriteAllBytes((Join-Path $dir "index.wasm"), $wasm)

# 1. A run over the per-file limit fails and puts the originals back.
& powershell -ExecutionPolicy Bypass -File $script $dir -MaxFileMB 0 | Out-Null
Check ($LASTEXITCODE -eq 1) "an over-limit run exits 1"
Check ((Get-Item (Join-Path $dir "index.pck")).Length -eq $pck.Length) "over-limit run restores index.pck"
Check (-not (Test-Path "$dir-itch.zip")) "over-limit run leaves no zip"
Check ((@(Get-ChildItem $dir -Filter "*.orig").Count + @(Get-ChildItem $dir -Filter "*.tmp").Count) -eq 0) "over-limit run leaves no .orig or .tmp"

# 2. A good run.
& powershell -ExecutionPolicy Bypass -File $script $dir | Out-Null
Check ($LASTEXITCODE -eq 0) "a good run exits 0"
$b = [IO.File]::ReadAllBytes((Join-Path $dir "index.pck"))
Check ($b[0] -eq 0x1f -and $b[1] -eq 0x8b) "index.pck is gzip under its own name"
Check ((Gunzip-Length (Join-Path $dir "index.pck")) -eq $pck.Length) "index.pck unpacks to the original length"
Check ((Get-Item (Join-Path $dir "index.pck")).Length -lt $pck.Length / 4) "index.pck shrank"
$h = [IO.File]::ReadAllBytes((Join-Path $dir "index.html"))
Check ($h[0] -ne 0x1f) "index.html is left alone"
Check (Test-Path "$dir-itch.zip") "the itch zip exists"
$z = [IO.Compression.ZipFile]::OpenRead("$dir-itch.zip")
$names = @($z.Entries | ForEach-Object { $_.FullName })
$z.Dispose()
Check ($names -contains "index.html") "index.html sits at the zip root"
Check (@($names | Where-Object { $_ -like "*.orig" -or $_ -like "*.tmp" }).Count -eq 0) "the zip holds no backups"

# 3. A second run is refused.
& powershell -ExecutionPolicy Bypass -File $script $dir | Out-Null
Check ($LASTEXITCODE -eq 1) "a second run is refused"

# 4. A failure while writing the zip (here: its path is an occupied folder)
#    restores the originals instead of leaving the export half gzipped.
$dir2 = Join-Path $root "web2"
New-Item -ItemType Directory -Force $dir2 | Out-Null
[IO.File]::WriteAllText((Join-Path $dir2 "index.html"), "<html></html>")
[IO.File]::WriteAllBytes((Join-Path $dir2 "index.pck"), $pck)
New-Item -ItemType Directory -Force "$dir2-itch.zip" | Out-Null
[IO.File]::WriteAllText((Join-Path "$dir2-itch.zip" "keep.txt"), "x")
& powershell -NonInteractive -ExecutionPolicy Bypass -File $script $dir2 | Out-Null
Check ($LASTEXITCODE -eq 1) "a failing zip step exits 1"
$b2 = [IO.File]::ReadAllBytes((Join-Path $dir2 "index.pck"))
Check ($b2.Length -eq $pck.Length -and -not ($b2[0] -eq 0x1f -and $b2[1] -eq 0x8b)) "a failing zip step restores the original index.pck"
Check (@(Get-ChildItem $dir2 -Filter "*.orig").Count -eq 0) "a failing zip step leaves no .orig"

Remove-Item -Recurse -Force $root
if ($fails) { exit 1 } else { Write-Host "ALL PASS"; exit 0 }
