<#
.SYNOPSIS
    Orvia Safe Storage Recovery Script (Strict Allowlist Mode)
.DESCRIPTION
    Safely calculates and deletes disposable compiler and build caches.
    Strictly protects release APKs, Windows ZIPs, rollback archives, and source code.
.PARAMETER ExecuteCleanup
    Switch parameter to actually perform deletion. If omitted, runs in Read-Only Preview mode.
#>
param (
    [switch]$ExecuteCleanup = $false
)

$ErrorActionPreference = "Stop"

$ProjectRoot = (Resolve-Path "$PSScriptRoot").Path
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  ORVIA SAFE STORAGE CLEANUP & RECOVERY" -ForegroundColor Cyan
Write-Host "  Project Root: $ProjectRoot" -ForegroundColor Cyan
Write-Host "  Mode: $(if ($ExecuteCleanup) { 'EXECUTION (DELETION)' } else { 'PREVIEW ONLY (READ-ONLY)' })" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan

# STRICT ALLOWLIST: Relative paths that are 100% disposable build/compiler caches
$AllowlistedRelativePaths = @(
    "build/rust_lib_orvia",
    "build/app/intermediates",
    "build/app/tmp",
    "build/windows/x64",
    "build/test_cache",
    "rust/target",
    ".dart_tool",
    "windows/flutter/ephemeral"
)

# STRICT PROTECTED PATHS: Must NEVER be modified or deleted
$ProtectedRelativePaths = @(
    "build/orvia-windows-x64-v3.0.7.zip",
    "build/backups",
    "build/app/outputs/flutter-apk/app-release.apk",
    "ghpage",
    "lib",
    "android/app/src",
    "assets",
    ".git"
)

function Get-FolderSize([string]$Path) {
    if (-not (Test-Path $Path)) { return 0 }
    $measure = Get-ChildItem -Path $Path -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum
    if ($measure -and $measure.Sum) { return $measure.Sum }
    return 0
}

$TotalBytesToFree = 0
$ValidCandidates = @()

Write-Host "`n[1] Validating Candidates against Safety Constraints..." -ForegroundColor Green

foreach ($rel in $AllowlistedRelativePaths) {
    $fullPath = [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot $rel))

    # Constraint 1: Must reside inside ProjectRoot
    if (-not $fullPath.StartsWith($ProjectRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-Error "CRITICAL SAFETY VIOLATION: Path $fullPath escapes project root! Aborting."
        exit 1
    }

    # Constraint 2: Must NOT collide with any protected path
    foreach ($prot in $ProtectedRelativePaths) {
        $protFull = [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot $prot))
        if ($fullPath -eq $protFull -or $protFull.StartsWith($fullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            Write-Error "CRITICAL SAFETY VIOLATION: Path $fullPath overlaps protected path $protFull! Aborting."
            exit 1
        }
    }

    # Constraint 3: Must exist on disk
    if (Test-Path $fullPath) {
        # Constraint 4: Refuse symlinks/reparse points
        $item = Get-Item $fullPath -Force
        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            Write-Warning "SKIPPING ${rel}: Reparse point (junction/symlink) detected."
            continue
        }

        $size = Get-FolderSize $fullPath
        $TotalBytesToFree += $size
        $ValidCandidates += [PSCustomObject]@{
            RelativePath = $rel
            FullPath     = $fullPath
            SizeBytes    = $size
            SizeMB       = [Math]::Round($size / 1MB, 2)
            SizeGB       = [Math]::Round($size / 1GB, 2)
        }
    } else {
        Write-Host "  [-] $rel : Not found (already clean)" -ForegroundColor DarkGray
    }
}

Write-Host "`n[2] Candidate Inventory & Space Recovery Analysis:" -ForegroundColor Green
$ValidCandidates | Format-Table -Property RelativePath, SizeMB, SizeGB -AutoSize

$TotalGB = [Math]::Round($TotalBytesToFree / 1GB, 2)
Write-Host "`nTotal Reclaimable Space: $TotalGB GB ($($TotalBytesToFree.ToString('N0')) bytes)" -ForegroundColor Cyan

if (-not $ExecuteCleanup) {
    Write-Host "`n>>> PREVIEW FINISHED: No files were deleted. <<<" -ForegroundColor Yellow
    Write-Host "To execute deletion and reclaim ~$TotalGB GB, run:" -ForegroundColor Yellow
    Write-Host "powershell -ExecutionPolicy Bypass -File .\safe_storage_cleanup.ps1 -ExecuteCleanup" -ForegroundColor White
    exit 0
}

Write-Host "`n[3] Executing Safe Cache Deletion..." -ForegroundColor Yellow
foreach ($cand in $ValidCandidates) {
    Write-Host "  Deleting $($cand.RelativePath) ($($cand.SizeMB) MB)..." -NoNewline
    try {
        Remove-Item -Path $cand.FullPath -Recurse -Force -ErrorAction Stop
        Write-Host " [DONE]" -ForegroundColor Green
    } catch {
        Write-Host " [FAILED: $_]" -ForegroundColor Red
    }
}

Write-Host "`nCleanup Complete! Successfully freed ~$TotalGB GB of storage." -ForegroundColor Green
