<#
.SYNOPSIS
    Finds and clears the two process leftovers that make the Godot editor hang.

.DESCRIPTION
    Two kinds of debris accumulate while working on this project, both
    documented in CLAUDE.md:

      1. Orphaned game processes. The editor launches the game as a child
         (--remote-debug ... --editor-pid <N>). If the editor is force-killed
         after a hang, that child keeps running with no parent and no visible
         window -- it holds GPU resources, file handles and the remote-debug
         port until something kills it.

      2. Stray godot-ai backends. The Godot AI MCP bridge is single-client.
         More than one backend fights over the port, and because the plugin
         services its commands on the editor's MAIN THREAD, that contention
         can block the UI thread -- which Windows records as an AppHangB1
         ("not responding"), not as a crash.

    These feed each other: a hang makes you kill the editor, which orphans a
    game process, whose contention makes the next hang more likely.

    Real editor processes (--editor) are NEVER touched.

.PARAMETER Kill
    Actually terminate what is found. Without this the script only reports,
    so it is safe to run at any time.

.PARAMETER AllBackends
    Also treat godot-ai backends as strays when exactly one is running
    alongside a live editor. By default that case is left alone, since it is
    the healthy configuration. Use this when recovering from
    "A different Godot AI backend is already running".

.EXAMPLE
    .\tools\cleanup-godot-processes.ps1
    Report only -- shows what would be cleaned.

.EXAMPLE
    .\tools\cleanup-godot-processes.ps1 -Kill
    Clean up orphaned game processes and duplicate backends.

.EXAMPLE
    .\tools\cleanup-godot-processes.ps1 -Kill -AllBackends
    Full reset of the MCP bridge; the editor plugin reconnects on its own.
#>
[CmdletBinding()]
param(
    [switch]$Kill,
    [switch]$AllBackends
)

$ErrorActionPreference = 'Stop'

function Write-Section($text) {
    Write-Host ""
    Write-Host $text -ForegroundColor Cyan
}

# --- Gather -----------------------------------------------------------------

$godot = @(Get-CimInstance Win32_Process -Filter "Name LIKE '%Godot%'" -ErrorAction SilentlyContinue)
$backends = @(Get-CimInstance Win32_Process -Filter "Name LIKE '%godot-ai%'" -ErrorAction SilentlyContinue)

$editors = @()
$games = @()

foreach ($p in $godot) {
    $cmd = $p.CommandLine
    if ($null -eq $cmd) { continue }
    if ($cmd -match '--remote-debug') {
        $games += $p
    }
    elseif ($cmd -match '--editor') {
        $editors += $p
    }
}

# A game process is orphaned when the editor that spawned it is gone.
$orphans = @()
foreach ($g in $games) {
    $parentPid = $null
    if ($g.CommandLine -match '--editor-pid\s+(\d+)') {
        $parentPid = [int]$Matches[1]
    }
    if ($null -eq $parentPid) { continue }

    $parent = Get-Process -Id $parentPid -ErrorAction SilentlyContinue
    if ($null -eq $parent) {
        $orphans += [pscustomobject]@{
            ProcessId  = $g.ProcessId
            ParentPid  = $parentPid
            Started    = $g.CreationDate
        }
    }
}

# --- Report -----------------------------------------------------------------

Write-Section "Editors (never touched)"
if ($editors.Count -eq 0) {
    Write-Host "  none running"
} else {
    foreach ($e in $editors) {
        Write-Host "  PID $($e.ProcessId)  started $($e.CreationDate)"
    }
}

Write-Section "Orphaned game processes"
if ($orphans.Count -eq 0) {
    Write-Host "  none" -ForegroundColor Green
} else {
    foreach ($o in $orphans) {
        Write-Host "  PID $($o.ProcessId)  orphaned (parent editor $($o.ParentPid) is gone)  started $($o.Started)" -ForegroundColor Yellow
    }
}

# Decide which backends count as strays.
$strayBackends = @()
if ($backends.Count -gt 1) {
    # More than one is always wrong -- the bridge is single-client.
    $strayBackends = $backends
} elseif ($backends.Count -eq 1) {
    if ($AllBackends) {
        $strayBackends = $backends
    } elseif ($editors.Count -eq 0) {
        # A backend with no editor to serve is left over from a dead session.
        $strayBackends = $backends
    }
}

Write-Section "godot-ai backends"
if ($backends.Count -eq 0) {
    Write-Host "  none running" -ForegroundColor Green
} else {
    foreach ($b in $backends) {
        $isStray = $false
        foreach ($s in $strayBackends) {
            if ($s.ProcessId -eq $b.ProcessId) { $isStray = $true }
        }
        if ($isStray) {
            Write-Host "  PID $($b.ProcessId)  STRAY  started $($b.CreationDate)" -ForegroundColor Yellow
        } else {
            Write-Host "  PID $($b.ProcessId)  ok     started $($b.CreationDate)"
        }
    }
    if ($backends.Count -gt 1) {
        Write-Host "  -> $($backends.Count) backends for a single-client bridge; this is the hang pattern." -ForegroundColor Yellow
    }
}

# --- Act --------------------------------------------------------------------

$targets = @()
foreach ($o in $orphans) { $targets += $o.ProcessId }
foreach ($s in $strayBackends) { $targets += $s.ProcessId }

Write-Section "Result"
if ($targets.Count -eq 0) {
    Write-Host "  Nothing to clean." -ForegroundColor Green
    exit 0
}

if (-not $Kill) {
    Write-Host "  $($targets.Count) process(es) would be terminated."
    Write-Host "  Re-run with -Kill to do it."
    exit 0
}

$killed = 0
foreach ($procId in $targets) {
    try {
        Stop-Process -Id $procId -Force -ErrorAction Stop
        Write-Host "  killed PID $procId" -ForegroundColor Green
        $killed++
    } catch {
        Write-Host "  could not kill PID $procId : $($_.Exception.Message)" -ForegroundColor Red
    }
}
Write-Host ""
Write-Host "  Cleaned $killed of $($targets.Count)." -ForegroundColor Green
if ($strayBackends.Count -gt 0) {
    Write-Host "  The editor plugin reconnects on its own; restarting the MCP client is not required."
}
