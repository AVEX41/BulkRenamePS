# ============================================
# Skript: BulkRenamePS.ps1
# Formål: Gir nytt navn i bulk basert på mønster spesifisert
# Forfatter: Aleksander Hoff (GH:@AVEX41)
# Dato: Later
# ============================================

# :TODO: Create the help comments for PS

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

Write-Output $MatchedFiles
Write-Output $RenameCandidates

# :TODO: Write the renamed files, and ask for confirmation 
# :TODO: Create backup folder with old files
#  :TODO: Run