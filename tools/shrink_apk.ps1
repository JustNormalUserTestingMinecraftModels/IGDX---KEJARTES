<#
.SYNOPSIS
    Shrinks a Godot Android APK by deflating its .ctex textures, then aligns
    and re-signs it with the same debug key Godot signs with.

.DESCRIPTION
    Godot's Android exporter stores every .ctex uncompressed, and our
    VRAM-compressed (ASTC) art is mostly transparent, so it deflates about 6x.
    The result is byte-identical inside: same pixels, same GPU memory.

      1. repack  - tools/ShrinkApk.java: .ctex deflated, the rest as it was
      2. align   - zipalign -P 16 -f 4
      3. sign    - apksigner, Godot's debug keystore (installs over builds
                   signed on this PC; another PC's key differs)
      4. verify  - ShrinkApk.java verify, zipalign -c, apksigner verify

    Every step writes a temp file beside -Out; only a fully verified APK is
    moved onto -Out, so a failure or Ctrl+C never leaves a broken output and
    never deletes a good one from an earlier run. The input APK is never
    written. The JDK, SDK and keystore come from Godot's editor settings.

    Design: docs/superpowers/specs/2026-10-02-apk-size-design.md
    How-to: docs/superpowers/apk-build.md

.PARAMETER Apk
    The APK Godot exported.

.PARAMETER Out
    Where to write the result. Default: <Apk name>-small.apk beside it.

.PARAMETER EditorSettings
    Godot's editor settings file, read for the SDK, JDK and debug keystore.

.PARAMETER SdkPath
    Android SDK. Default: editor setting export/android/android_sdk_path.

.PARAMETER JavaHome
    JDK. Default: editor setting export/android/java_sdk_path.

.PARAMETER Keystore
    Signing keystore. Default: editor setting export/android/debug_keystore.

.PARAMETER KeystorePass
    Its password. Default: editor setting export/android/debug_keystore_pass.

.PARAMETER KeyAlias
    Key alias. Default: editor setting export/android/debug_keystore_user,
    else androiddebugkey.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools/shrink_apk.ps1 "C:\Builds\Kejartes.apk"
#>
param(
    [Parameter(Mandatory = $true)][string]$Apk,
    [string]$Out = "",
    [string]$EditorSettings = (Join-Path $env:APPDATA "Godot\editor_settings-4.6.tres"),
    [string]$SdkPath = "",
    [string]$JavaHome = "",
    [string]$Keystore = "",
    [string]$KeystorePass = "",
    [string]$KeyAlias = ""
)

$ErrorActionPreference = "Stop"

# The value of a `key = "value"` line, with the .tres escapes (\" and \\) undone.
function Read-EditorSetting([string]$Key) {
    if (-not (Test-Path -LiteralPath $EditorSettings)) {
        throw "Godot editor settings not found at $EditorSettings. Pass -EditorSettings (a newer Godot writes editor_settings-<version>.tres), or pass the values as parameters."
    }
    $pattern = '^' + [regex]::Escape($Key) + ' = "(.*)"$'
    $hit = Select-String -LiteralPath $EditorSettings -Pattern $pattern | Select-Object -First 1
    if ($hit) { return ($hit.Matches[0].Groups[1].Value -replace '\\(.)', '$1') }
    return ""
}

function Get-Required([string]$Value, [string]$Setting) {
    if (-not $Value) {
        throw "'$Setting' is empty: set it in Godot's Editor Settings, or pass it as a parameter."
    }
    return $Value
}

function Invoke-Tool([string]$Exe, [string[]]$ToolArgs) {
    & $Exe @ToolArgs
    if ($LASTEXITCODE -ne 0) { throw "$(Split-Path -Leaf $Exe) failed (exit $LASTEXITCODE)." }
}

# True when Other is the very file at Path under any spelling (8.3 short names,
# links): hold Path open exclusively, then see whether Other can still be opened.
function Test-SameFile([string]$Path, [string]$Other) {
    if (-not (Test-Path -LiteralPath $Other -PathType Leaf)) { return $false }
    try { $lock = [IO.File]::Open($Path, 'Open', 'Read', 'None') }
    catch [IO.IOException] { throw "The input APK is open in another program (Godot still exporting?). Close it and retry." }
    try {
        try { [IO.File]::Open($Other, 'Open', 'Read', 'ReadWrite').Dispose(); return $false }
        catch [IO.IOException] { return $true }
    } finally { $lock.Dispose() }
}

$Apk = (Resolve-Path -LiteralPath $Apk).Path
if (-not $Out) {
    $Out = Join-Path (Split-Path -Parent $Apk) ([IO.Path]::GetFileNameWithoutExtension($Apk) + "-small.apk")
}
# Full path (relative to PowerShell's location, `.` and `..` folded), then a
# same-file check: the input is never written, so -Out may not be it.
$Out = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Out)
if ($Out -eq $Apk -or (Test-SameFile $Apk $Out)) {
    throw "-Out is the input APK, or is open in another program: $Out"
}

if (-not $SdkPath) { $SdkPath = Read-EditorSetting "export/android/android_sdk_path" }
if (-not $JavaHome) { $JavaHome = Read-EditorSetting "export/android/java_sdk_path" }
if (-not $Keystore) { $Keystore = Read-EditorSetting "export/android/debug_keystore" }
if (-not $KeystorePass) { $KeystorePass = Read-EditorSetting "export/android/debug_keystore_pass" }
if (-not $KeyAlias -and (Test-Path -LiteralPath $EditorSettings)) {
    $KeyAlias = Read-EditorSetting "export/android/debug_keystore_user"
}
if (-not $KeyAlias) { $KeyAlias = "androiddebugkey" }
$SdkPath = Get-Required $SdkPath "export/android/android_sdk_path"
$JavaHome = Get-Required $JavaHome "export/android/java_sdk_path"
$Keystore = Get-Required $Keystore "export/android/debug_keystore"
$KeystorePass = Get-Required $KeystorePass "export/android/debug_keystore_pass"

$java = Join-Path $JavaHome "bin\java.exe"
$buildTools = Get-ChildItem -Directory -LiteralPath (Join-Path $SdkPath "build-tools") |
    Sort-Object { [version]($_.Name -replace '[^0-9.].*$', '') } |
    Select-Object -Last 1
if (-not $buildTools) { throw "No build-tools under $SdkPath. Install them with the Android SDK Manager." }
$zipalign = Join-Path $buildTools.FullName "zipalign.exe"
$apksigner = Join-Path $buildTools.FullName "apksigner.bat"
$repacker = Join-Path $PSScriptRoot "ShrinkApk.java"
foreach ($needed in @($java, $zipalign, $apksigner, $Keystore, $repacker)) {
    if (-not (Test-Path -LiteralPath $needed)) { throw "Missing: $needed" }
}

# apksigner.bat runs `java` from PATH; the password reaches it by name only.
# All three are put back afterwards, so a caller's session is left as it was.
$savedPath = $env:PATH
$savedJavaHome = $env:JAVA_HOME
$env:JAVA_HOME = $JavaHome
$env:PATH = (Join-Path $JavaHome "bin") + ";" + $env:PATH
$env:SHRINK_APK_KS_PASS = $KeystorePass

$repacked = "$Out.repacked.tmp"
$aligned = "$Out.aligned.tmp"
$signed = "$Out.signed.tmp"
$failed = $false
try {
    Write-Host "1/4 repacking textures..."
    Invoke-Tool $java @($repacker, "repack", $Apk, $repacked)
    Write-Host "2/4 aligning..."
    Invoke-Tool $zipalign @("-P", "16", "-f", "4", $repacked, $aligned)
    Write-Host "3/4 signing..."
    Invoke-Tool $apksigner @("sign", "--ks", $Keystore, "--ks-key-alias", $KeyAlias,
        "--ks-pass", "env:SHRINK_APK_KS_PASS", "--key-pass", "env:SHRINK_APK_KS_PASS",
        "--out", $signed, $aligned)
    Write-Host "4/4 verifying..."
    Invoke-Tool $java @($repacker, "verify", $Apk, $signed)
    Invoke-Tool $zipalign @("-c", "-P", "16", "4", $signed)
    Invoke-Tool $apksigner @("verify", $signed)
    Move-Item -LiteralPath $signed -Destination $Out -Force
} catch {
    $failed = $true
    Write-Host "shrink_apk: $_" -ForegroundColor Red
} finally {
    Remove-Item -LiteralPath $repacked, $aligned, $signed, "$signed.idsig" -ErrorAction SilentlyContinue
    Remove-Item Env:SHRINK_APK_KS_PASS -ErrorAction SilentlyContinue
    $env:PATH = $savedPath
    $env:JAVA_HOME = $savedJavaHome
}

if ($failed) { exit 1 }
$before = (Get-Item -LiteralPath $Apk).Length / 1e6
$after = (Get-Item -LiteralPath $Out).Length / 1e6
Write-Host ("{0:N1} MB -> {1:N1} MB  {2}" -f $before, $after, $Out) -ForegroundColor Green
exit 0
