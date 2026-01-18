# ============================================
# Skript: BulkRenamePS.ps1
# Formål: Gir nytt navn i bulk basert på mønster spesifisert
# Forfatter: Aleksander Hoff (GH:@AVEX41)
# Dato: Later
# ============================================

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