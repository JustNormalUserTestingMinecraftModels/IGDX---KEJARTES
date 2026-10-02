<#
.SYNOPSIS
    Gzips a Godot Web export in place for itch.io and zips it for upload.

.DESCRIPTION
    itch.io allows at most 200 MB per file, and our raw index.pck is ~580 MB.
    itch.io sends any file whose content is gzip with content-encoding: gzip
    under its own name, and the browser unpacks it before Godot reads it. So
    this gzips *.pck, *.wasm and *.js in place, proves each one unpacks to a
    byte-identical original (SHA-256), checks every file against the limit,
    and writes <Folder>-itch.zip with index.html at its root.

    Any failure puts the originals back and leaves no zip. A folder that was
    already processed is refused.

    Design: docs/superpowers/specs/2026-10-02-web-build-design.md
    How-to: docs/superpowers/apk-build.md, "Web build"

.PARAMETER Folder
    The folder Godot exported the Web preset into (it holds index.html).

.PARAMETER MaxFileMB
    itch.io's per-file limit in MB.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools/shrink_web.ps1 "C:\Users\user\Downloads\KejarTes-web\release"
#>
param(
    [Parameter(Mandatory = $true)][string]$Folder,
    [int]$MaxFileMB = 200
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Test-Gzip([string]$Path) {
    $fs = [IO.File]::OpenRead($Path)
    try { return ($fs.ReadByte() -eq 0x1f -and $fs.ReadByte() -eq 0x8b) } finally { $fs.Dispose() }
}

function Compress-GzipFile([string]$Source, [string]$Target) {
    $in = [IO.File]::OpenRead($Source)
    $out = [IO.File]::Create($Target)
    try {
        $gz = New-Object IO.Compression.GZipStream($out, [IO.Compression.CompressionLevel]::Optimal)
        try { $in.CopyTo($gz) } finally { $gz.Dispose() }
    } finally { $in.Dispose(); $out.Dispose() }
}

# SHA-256 of the bytes a gzip file unpacks to, in Get-FileHash's format.
function Get-GunzipHash([string]$Path) {
    $in = [IO.File]::OpenRead($Path)
    try {
        $gz = New-Object IO.Compression.GZipStream($in, [IO.Compression.CompressionMode]::Decompress)
        try {
            $sha = [Security.Cryptography.SHA256]::Create()
            return ([BitConverter]::ToString($sha.ComputeHash($gz)) -replace '-', '')
        } finally { $gz.Dispose() }
    } finally { $in.Dispose() }
}

$Folder = (Resolve-Path -LiteralPath $Folder).Path.TrimEnd('\')
if (-not (Test-Path -LiteralPath (Join-Path $Folder "index.html"))) {
    Write-Host "shrink_web: no index.html in $Folder. Pass the folder the Web preset exported into." -ForegroundColor Red
    exit 1
}
$targets = @(Get-ChildItem -LiteralPath $Folder -File | Where-Object { $_.Extension -in '.pck', '.wasm', '.js' })
foreach ($t in $targets) {
    if (Test-Gzip $t.FullName) {
        Write-Host "shrink_web: $($t.Name) is already gzipped. Export again before running this." -ForegroundColor Red
        exit 1
    }
}

$zip = "$Folder-itch.zip"
$moved = @()
$failed = $false
$before = (Get-ChildItem -LiteralPath $Folder -File | Measure-Object Length -Sum).Sum
try {
    foreach ($t in $targets) {
        $orig = $t.FullName
        $tmp = "$orig.gz.tmp"
        $want = (Get-FileHash -LiteralPath $orig -Algorithm SHA256).Hash
        Compress-GzipFile $orig $tmp
        if ((Get-GunzipHash $tmp) -ne $want) { throw "$($t.Name): the gzip copy does not unpack to the original." }
        Move-Item -LiteralPath $orig -Destination "$orig.orig"
        $moved += $orig
        Move-Item -LiteralPath $tmp -Destination $orig
        Write-Host ("{0}: {1:N1} MB -> {2:N1} MB" -f $t.Name, ((Get-Item -LiteralPath "$orig.orig").Length / 1e6), ((Get-Item -LiteralPath $orig).Length / 1e6))
    }
    $limit = [double]$MaxFileMB * 1e6
    $big = @(Get-ChildItem -LiteralPath $Folder -File | Where-Object { $_.Extension -ne '.orig' -and $_.Length -gt $limit })
    if ($big.Count) { throw ("over itch.io's {0} MB per-file limit: {1}" -f $MaxFileMB, (($big | ForEach-Object Name) -join ', ')) }
    # Zip a copy of the folder without the .orig backups, and only delete the
    # backups once the zip exists: a failed zip (disk full) can still restore.
    if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip }
    $stage = "$Folder.zip-stage"
    if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
    New-Item -ItemType Directory -Path $stage | Out-Null
    try {
        Get-ChildItem -LiteralPath $Folder -File | Where-Object { $_.Extension -ne '.orig' } |
            ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $stage }
        [IO.Compression.ZipFile]::CreateFromDirectory($stage, $zip, [IO.Compression.CompressionLevel]::Optimal, $false)
    } finally { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue }
    foreach ($m in $moved) { Remove-Item -LiteralPath "$m.orig" }
    $moved = @()
} catch {
    $failed = $true
    Write-Host "shrink_web: $_" -ForegroundColor Red
} finally {
    if ($failed) {
        foreach ($m in $moved) { if (Test-Path -LiteralPath "$m.orig") { Move-Item -LiteralPath "$m.orig" -Destination $m -Force } }
        Get-ChildItem -LiteralPath $Folder -Filter "*.gz.tmp" | Remove-Item
        if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip }
    }
}
if ($failed) { exit 1 }
$after = (Get-ChildItem -LiteralPath $Folder -File | Measure-Object Length -Sum).Sum
Write-Host ("{0:N1} MB -> {1:N1} MB  {2}" -f ($before / 1e6), ($after / 1e6), $zip) -ForegroundColor Green
exit 0
