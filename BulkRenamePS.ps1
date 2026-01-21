# ============================================
# Script: BulkRenamePS.ps1
# Purpose: Renames files in bulk based on a specified pattern
# Author: Aleksander Hoff (GH:@AVEX41)
# Date: Later
# ============================================

<#
.SYNOPSIS
Renames files in bulk based on a specified pattern

.DESCRIPTION
The script uses the current working directory as the default Path, but this can be overridden by supplying a Path. 
Note this is non-recursive.
The script then asks for a pattern for the files you want to change, e.g. IMG_6769.cr2 can be described as [Name]_[Nr].cr2.
This can be used to rename to Result_6769.cr2 using Result_[Nr].cr2. It is very important to use brackets [], Or unexpected behaviour may occur.

.PARAMETER Path
PATH where files are renamed, non-recursive

.EXAMPLE
Enter an input pattern using variables in square brackets (example: [Prefix]_[NR].cr2). Will only affect files with matching pattern
Input pattern: [Name]_[Nr].png
Enter an output pattern using captured variables (example: Result_[NR].cr2).
Leave empty to keep the original filename.
Output pattern: Result_[Nr].png
Preview (max 10):
IMG_8557.png -> Result_8557.png
IMG_8558.png -> Result_8558.png
IMG_8559.png -> Result_8559.png
IMG_8560.png -> Result_8560.png
IMG_8569.png -> Result_8569.png
IMG_8580.png -> Result_8580.png
IMG_8584.png -> Result_8584.png
IMG_8587.png -> Result_8587.png
Proceed with rename? (Y/N): y
Renamed: IMG_8557.png -> Result_8557.png
Renamed: IMG_8558.png -> Result_8558.png
Renamed: IMG_8559.png -> Result_8559.png
Renamed: IMG_8560.png -> Result_8560.png
Renamed: IMG_8569.png -> Result_8569.png
Renamed: IMG_8580.png -> Result_8580.png
Renamed: IMG_8584.png -> Result_8584.png
Renamed: IMG_8587.png -> Result_8587.png
Done.

.EXAMPLE
.\BulkRenamePS.ps1 .\Documents\TextDocuments
Enter an input pattern using variables in square brackets (example: [Prefix]_[NR].cr2). Will only affect files with matching pattern
Input pattern: [FileName].txt
"Enter an output pattern using captured variables (example: Result_[NR].cr2).
Leave empty to keep the original filename.
Output pattern: [FileName].md
Preview (max 10):
README.txt -> README.md
Proceed with rename? (Y/N): y
Renamed: README.txt -> README.md
Done.

#>

# Gathering or populating the Path variable
param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Path = (Get-Location).Path
)

# Checking if the path is valid, if not: 
# the error action is to stop and inform user
try { $ResolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path } 
catch { Write-Error "Invalid path: $Path"; exit 1 }

# Ask the user for an input pattern (supports variables in square brackets)
Write-Output "Enter an input pattern using variables in square brackets (example: [Prefix]_[NR].cr2). Will only affect files with matching pattern"
# Reads from user
$InputPattern = Read-Host -Prompt "Input pattern"
# Stop if user doesn't comply
if ([string]::IsNullOrWhiteSpace($InputPattern)) { throw 'Cancelled by user.' }

$Pattern = $InputPattern

# Ask the user for an output pattern that can reference captured variables
Write-Output "Enter an output pattern using captured variables (example: Result_[NR].cr2)."
Write-Output "Leave empty to keep the original filename."
$OutputPattern = Read-Host -Prompt "Output pattern"
if ([string]::IsNullOrWhiteSpace($OutputPattern)) { $OutputPattern = '' }

# Build a filesystem glob by replacing variable tokens with '*' so Get-ChildItem can prefilter
# Regex: replace anything within [] with * for the Get-ChildItem later
$GlobPattern = $InputPattern -replace '\[[^\]]+\]', '*'
if ([string]::IsNullOrWhiteSpace($GlobPattern)) { $GlobPattern = '*.*' }

# Collect candidate files using the glob
$MatchedFiles = Get-ChildItem -Path (Join-Path $ResolvedPath $GlobPattern) -File -ErrorAction SilentlyContinue

# Convert the input pattern into a regex with named capture groups for variables
function Convert-PatternToRegex {
    param([string]$pattern)
    $sb = New-Object System.Text.StringBuilder
    $sb.Append('^') | Out-Null
    $i = 0
    while ($i -lt $pattern.Length) {
        $c = $pattern[$i]
        if ($c -eq '[') {
            $j = $pattern.IndexOf(']', $i + 1)
            if ($j -lt 0) { break }
            $name = $pattern.Substring($i + 1, $j - $i - 1)
            # non-greedy capture for the variable
            $sb.Append("(?<$name>.+?)") | Out-Null
            $i = $j + 1
            continue
        }
        if ($c -eq '*') { $sb.Append('.*') | Out-Null; $i++; continue }
        # escape other characters
        $sb.Append([regex]::Escape($c)) | Out-Null
        $i++
    }
    $sb.Append('$') | Out-Null
    return $sb.ToString()
}

$RegexPattern = Convert-PatternToRegex $InputPattern
$Regex = [regex]$RegexPattern

# Extract variable names present in the input pattern
$VarNames = [regex]::Matches($InputPattern, '\[(.*?)\]') | ForEach-Object { $_.Groups[1].Value }

# Filter the matched files by ensuring the filename matches the constructed regex
$MatchedFiles = $MatchedFiles | Where-Object { $Regex.IsMatch($_.Name) }


# Create rename candidates by substituting captured variables into the output pattern
$RenameCandidates = @()
foreach ($f in $MatchedFiles) {
    $m = $Regex.Match($f.Name)
    if (-not $m.Success) { continue }
    if ([string]::IsNullOrWhiteSpace($OutputPattern)) {
        $newName = $f.Name
    }
    else {
        $newName = $OutputPattern
        foreach ($var in $VarNames) {
            $val = $m.Groups[$var].Value
            $newName = $newName.Replace("[$var]", $val)
        }
    }
    $RenameCandidates += [PSCustomObject]@{
        OriginalFullPath = $f.FullName
        OriginalName     = $f.Name
        NewName          = $newName
        NewFullPath      = (Join-Path $ResolvedPath $newName)
    }
}

# Write-Output $MatchedFiles
# Write-Output $RenameCandidates

$PerformRename = $false # Default: no, ask for confirmation
$CreateBackup = $true # Always create a backup
$PreviewLimit = 10 # How many previews

# Print a preview (max $PreviewLimit lines) of OriginalName -> NewName
Write-Output "Preview (max $PreviewLimit):"
$RenameCandidates | Select-Object -First $PreviewLimit | ForEach-Object {
    Write-Output ("{0} -> {1}" -f $_.OriginalName, $_.NewName)
}

if ($RenameCandidates.Count -eq 0) {
    Write-Output "No matching files found. Exiting."
    exit 0
}

# Ask for confirmation unless the user pre-enabled $PerformRename
if (-not $PerformRename) {
    $confirm = Read-Host -Prompt "Proceed with rename? (Y/N)"
    if ($confirm -ne 'Y' -and $confirm -ne 'y') { Write-Output 'Cancelled by user.'; exit 0 }
}

# Create backup folder if requested
if ($CreateBackup) {
    $BackupDir = Join-Path $ResolvedPath ("_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')")
    try { New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null }
    catch { Write-Warning "Could not create backup folder: $BackupDir"; $CreateBackup = $false }
}

# Perform the renames (copy originals to backup, then move originals to new names)
foreach ($c in $RenameCandidates) {
    if (Test-Path -LiteralPath $c.NewFullPath) {
        Write-Warning "Target exists, skipping: $($c.NewName)"
        continue
    }

    if ($CreateBackup) {
        try { Copy-Item -LiteralPath $c.OriginalFullPath -Destination (Join-Path $BackupDir $c.OriginalName) -Force }
        catch { Write-Warning "Failed to backup $($c.OriginalName): $_" }
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