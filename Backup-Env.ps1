<#
.SYNOPSIS
    .env Files to Bitwarden Backup Script (Windows)
    Recursively finds all .env files and backs them up to Bitwarden as Secure Notes

.DESCRIPTION
    This script searches for all files starting with ".env" in the specified directory
    and its subdirectories, then securely backs them up to Bitwarden as Secure Notes.
    It checks for existing items and updates them instead of creating duplicates.

.PARAMETER Directory
    The directory to search for .env files (default: current directory)

.PARAMETER Prefix
    A prefix to add to all Bitwarden item names (optional)

.PARAMETER Verbose
    Enable verbose output

.EXAMPLE
    .\Backup-Env.ps1
    Search current directory for .env files

.EXAMPLE
    .\Backup-Env.ps1 -Directory "C:\Projects\MyApp"
    Search specific directory

.EXAMPLE
    .\Backup-Env.ps1 -Directory ".\config" -Prefix "Production Secrets"
    Search directory with prefix for item names

.EXAMPLE
    .\Backup-Env.ps1 -Verbose
    Enable verbose output

#>

[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [string]$Directory = ".",
    
    [Parameter(Position = 1)]
    [string]$Prefix = "",
    
    [switch]$Force = $false
)

# Helper functions
function Write-ColorOutput {
    param(
        [string]$Message,
        [ConsoleColor]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-Info {
    param([string]$Message)
    Write-ColorOutput "[INFO] $Message" Cyan
}

function Write-Success {
    param([string]$Message)
    Write-ColorOutput "[SUCCESS] $Message" Green
}

function Write-Warning {
    param([string]$Message)
    Write-ColorOutput "[WARNING] $Message" Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Test-Dependencies {
    $missing = @()
    
    # Check for Bitwarden CLI
    try {
        $null = Get-Command bw -ErrorAction Stop
    }
    catch {
        $missing += "bw (Bitwarden CLI)"
    }
    
    if ($missing.Count -gt 0) {
        Write-Error "Missing dependencies: $($missing -join ', ')"
        Write-Info "Install missing dependencies:"
        Write-Info "  npm install -g @bitwarden/cli"
        Write-Info "  # Or with Chocolatey:"
        Write-Info "  choco install bitwarden-cli"
        exit 1
    }
}

function Test-BitwardenAuth {
    # Check if session is set
    if (-not $env:BW_SESSION) {
        # Check vault status
        try {
            $status = bw status | ConvertFrom-Json
            if ($status.status -ne "unlocked") {
                Write-Error "Bitwarden vault is locked or not authenticated"
                Write-Info "Please run:"
                Write-Info "  bw login"
                Write-Info "  bw unlock"
                Write-Info "Then set the environment variable:"
                Write-Info "  `$env:BW_SESSION = '<your-session-key>'"
                exit 1
            }
        }
        catch {
            Write-Error "Failed to check Bitwarden status. Please ensure you're logged in."
            exit 1
        }
    }
}

function Find-EnvFiles {
    param([string]$SearchDir)
    
    try {
        # Find all files starting with .env, excluding common temp files
        $envFiles = Get-ChildItem -Path $SearchDir -Recurse -Filter ".env*" -File | 
            Where-Object { $_.Name -notlike "*.swp" -and $_.Name -notlike "*.tmp" }
        
        if ($envFiles.Count -eq 0) {
            Write-Warning "No .env files found in '$SearchDir'"
            return @()
        }
        
        return $envFiles
    }
    catch {
        Write-Error "Error searching for .env files: $_"
        return @()
    }
}

function New-ItemName {
    param(
        [string]$FilePath,
        [string]$BaseDir,
        [string]$Prefix
    )
    
    # Get relative path
    $relPath = Resolve-Path -Relative $FilePath
    if ($relPath.StartsWith(".\")) {
        $relPath = $relPath.Substring(2)
    }
    
    # Build item name
    if ($Prefix) {
        return "$Prefix - $relPath"
    }
    else {
        return $relPath
    }
}

function Get-ExistingItem {
    param([string]$ItemName)
    
    try {
        $items = bw list items --search $ItemName | ConvertFrom-Json
        $existing = $items | Where-Object { $_.name -eq $ItemName } | Select-Object -First 1
        
        if ($existing) {
            return $existing.id
        }
    }
    catch {
        # No existing items or error
    }
    
    return $null
}

function Backup-EnvFile {
    param(
        [System.IO.FileInfo]$File,
        [string]$BaseDir,
        [string]$Prefix
    )
    
    $itemName = New-ItemName -FilePath $File.FullName -BaseDir $BaseDir -Prefix $Prefix
    
    if ($VerbosePreference -eq 'Continue') {
        Write-Info "Processing: $($File.FullName)"
        Write-Info "Item name: $itemName"
    }
    
    # Read file content with UTF-8 encoding
    try {
        $content = Get-Content -Path $File.FullName -Raw -Encoding UTF8
    }
    catch {
        Write-Error "Failed to read file: $($File.FullName)"
        return $false
    }
    
    # Check if item already exists
    $existingId = Get-ExistingItem -ItemName $itemName
    
    # Create PowerShell object for the item
    $payloadObject = @{
        type = 2  # Secure Note
        name = $itemName
        notes = $content
        secureNote = @{
            type = 0
        }
    }
    
    # Add ID if updating
    if ($existingId) {
        if ($VerbosePreference -eq 'Continue') {
            Write-Info "Updating existing item: $existingId"
        }
        $payloadObject | Add-Member -NotePropertyName id -NotePropertyValue $existingId
        
        try {
            $jsonPayload = $payloadObject | ConvertTo-Json -Depth 10
            $result = $jsonPayload | bw edit item | ConvertFrom-Json
            
            if ($result.id) {
                Write-Success "Updated: $itemName"
                return $true
            }
        }
        catch {
            Write-Error "Failed to update: $itemName"
            return $false
        }
    }
    else {
        try {
            $jsonPayload = $payloadObject | ConvertTo-Json -Depth 10
            $result = $jsonPayload | bw create item | ConvertFrom-Json
            
            if ($result.id) {
                Write-Success "Created: $itemName (ID: $($result.id))"
                return $true
            }
        }
        catch {
            Write-Error "Failed to create: $itemName"
            return $false
        }
    }
    
    return $false
}

# Main execution
function Main {
    Write-Info ".env Files to Bitwarden Backup Script"
    Write-Info "====================================="
    
    # Check dependencies
    Test-Dependencies
    
    # Check Bitwarden authentication
    Test-BitwardenAuth
    
    # Resolve directory path
    try {
        $Directory = Resolve-Path $Directory | Select-Object -ExpandProperty Path
    }
    catch {
        Write-Error "Directory not found: $Directory"
        exit 1
    }
    
    if ($VerbosePreference -eq 'Continue') {
        Write-Info "Search directory: $Directory"
        Write-Info "Prefix: $(if ($Prefix) { $Prefix } else { '(none)' })"
    }
    
    # Find all .env files
    $envFiles = Find-EnvFiles -SearchDir $Directory
    
    if ($envFiles.Count -eq 0) {
        exit 0
    }
    
    # Process each file
    $fileCount = 0
    $successCount = 0
    $errorCount = 0
    
    foreach ($file in $envFiles) {
        $fileCount++
        
        if (Backup-EnvFile -File $file -BaseDir $Directory -Prefix $Prefix) {
            $successCount++
        }
        else {
            $errorCount++
        }
    }
    
    # Summary
    Write-Info "====================================="
    Write-Info "Backup Summary:"
    Write-Info "  Total files found: $fileCount"
    Write-Success "  Successfully backed up: $successCount"
    
    if ($errorCount -gt 0) {
        Write-Error "  Failed: $errorCount"
        exit 1
    }
    
    Write-Success "All .env files backed up successfully!"
}

# Check for help parameter
if ($args -contains '-h' -or $args -contains '--help' -or $args -contains 'help') {
    Get-Help $MyInvocation.MyCommand.Path -Full
    exit 0
}

# Run main function
Main
