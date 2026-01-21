
# ============================================
# Script: BulkRenamePS-Lite.ps1
# Purpose: Adds a prefix to all files in a directory (non-recursive)
# Author: Aleksander Hoff (GH:@AVEX41)
# Date: 21-01-2026
# ============================================

<#
.SYNOPSIS
Adds a prefix to all files in a directory (non-recursive).

.DESCRIPTION
This script takes a directory (default: current working directory) and adds a user-specified
prefix to every file name within that directory (non-recursive). It previews changes, asks for
confirmation, creates a backup folder, and then renames the files. Files that already start with
the prefix are skipped to avoid double-prefixing.

.PARAMETER Path
The path where files are renamed. Defaults to the current working directory. Non-recursive.

.PARAMETER Prefix
The prefix to add to each file. If not provided, the script will prompt for it.

.EXAMPLE
.\BulkRenamePrefix.ps1
Enter the prefix to add (applied to all files): ProjectX_
Preview (max 10):
IMG_8557.png -> ProjectX_IMG_8557.png
IMG_8558.png -> ProjectX_IMG_8558.png
Proceed with rename? (Y/N): y
Renamed: IMG_8557.png -> ProjectX_IMG_8557.png
Renamed: IMG_8558.png -> ProjectX_IMG_8558.png
Done.

.EXAMPLE
.\BulkRenamePrefix.ps1 -Path .\Documents\TextDocuments -Prefix "ARCHIVE_"
#>

# Parameters
param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Path = (Get-Location).Path,

    [Parameter(Mandatory = $false)]
    [string]$Prefix
)

# Resolve and validate path
try {
    $ResolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
}
catch {
    Write-Error "Invalid path: $Path"
    exit 1
}

# Prompt for prefix if not supplied
if ([string]::IsNullOrWhiteSpace($Prefix)) {
    $Prefix = Read-Host -Prompt "Enter the prefix to add (applied to all files)"
}

# Validate the prefix
if ([string]::IsNullOrWhiteSpace($Prefix)) {
    throw 'Cancelled by user (empty prefix).'
}

# Ensure prefix does not contain invalid filename characters
$invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
if ($Prefix.IndexOfAny($invalidChars) -ge 0) {
    $invalidList = ($invalidChars -join ' ').Replace("`0", "") # sanitize null char display
    throw "Prefix contains invalid filename characters. Invalid set: $invalidList"
}

# Gather files (non-recursive, files only)
$Files = Get-ChildItem -LiteralPath $ResolvedPath -File -ErrorAction SilentlyContinue

if ($null -eq $Files -or $Files.Count -eq 0) {
    Write-Output "No files found in: $ResolvedPath. Exiting."
    exit 0
}

# Options
$PreviewLimit = 10
$CreateBackup = $true
$PerformRename = $false
$SkipIfAlreadyPrefixed = $true

# Build rename candidates
$RenameCandidates = @()

foreach ($f in $Files) {
    $originalName = $f.Name

    if ($SkipIfAlreadyPrefixed -and $originalName.StartsWith($Prefix)) {
        continue
    }

    $newName = $Prefix + $originalName
    $RenameCandidates += [PSCustomObject]@{
        OriginalFullPath = $f.FullName
        OriginalName     = $originalName
        NewName          = $newName
        NewFullPath      = (Join-Path $ResolvedPath $newName)
    }
}

if ($RenameCandidates.Count -eq 0) {
    Write-Output "No files require renaming (all already prefixed or none found). Exiting."
    exit 0
}

# Preview
Write-Output "Preview (max $PreviewLimit):"
$RenameCandidates | Select-Object -First $PreviewLimit | ForEach-Object {
    Write-Output ("{0} -> {1}" -f $_.OriginalName, $_.NewName)
}

# Confirm
if (-not $PerformRename) {
    $confirm = Read-Host -Prompt "Proceed with rename? (Y/N)"
    if ($confirm -ne 'Y' -and $confirm -ne 'y') {
        Write-Output 'Cancelled by user.'
        exit 0
    }
}

# Create backup directory
if ($CreateBackup) {
    $BackupDir = Join-Path $ResolvedPath ("_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')")
    try {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    }
    catch {
        Write-Warning "Could not create backup folder: $BackupDir"
        $CreateBackup = $false
    }
}

# Perform rename
foreach ($c in $RenameCandidates) {
    if (Test-Path -LiteralPath $c.NewFullPath) {
        Write-Warning "Target exists, skipping: $($c.NewName)"
        continue
    }
        
    if ($CreateBackup) {
        try {
            Copy-Item -LiteralPath $c.OriginalFullPath -Destination (Join-Path $BackupDir $c.OriginalName) -Force
        }
        catch {
            Write-Warning "Failed to backup $($c.OriginalName): $_"
        }
    }
        
    try {
        Move-Item -LiteralPath $c.OriginalFullPath -Destination $c.NewFullPath -Force
        Write-Output ("Renamed: {0} -> {1}" -f $c.OriginalName, $c.NewName)
    }
    catch {
        Write-Error ("Failed to rename $($c.OriginalName): $_")
    }
}

Write-Output 'Done.'
``
