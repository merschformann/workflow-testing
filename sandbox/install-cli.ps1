# PS script to install the CLI

## Required: exports
## NEXTMV_API_KEY - nextmv api key
## NEXTMV_BASE_URL - the api base to fetch the files

# Exit on error
$ErrorActionPreference = "Stop"

# Check for required environment variables
if (-not $env:NEXTMV_API_KEY) {
    Write-Error "NEXTMV_API_KEY is required."
    return
}

# Prepare variables
$nextmvDir = "$env:USERPROFILE\.nextmv"
$cliPath = "$nextmvDir\nextmv.exe"
$nextmvBaseUrl = $env:NEXTMV_BASE_URL
if (-not $nextmvBaseUrl) {
    $nextmvBaseUrl = "https://api.cloud.nextmv.io"
}

# Detect architecture
$arch = "amd64"
if ([System.Environment]::Is64BitOperatingSystem -eq $false) {
    Write-Error "32-bit operating systems are not supported."
    return
}
# TODO: Add detection for ARM64

# Create the directory
if (-not (Test-Path $nextmvDir)) {
    New-Item -ItemType Directory -Force -Path $nextmvDir
}

# --> Check latest version
# Get presigned URL for the manifest
Write-Host "Checking latest Nextmv CLI version..."
$manifestUrl = "$nextmvBaseUrl/v0/internal/tools?file=cli/manifest.yml"
$manifestPresigned = Invoke-WebRequest -Uri $manifestUrl -Headers @{ "Authorization" = "Bearer $env:NEXTMV_API_KEY" } | ConvertFrom-Json
if (-not $manifestPresigned.url) {
    Write-Error "Failed to get the latest version of the CLI."
    return
}
# Download the YAML manifest and extract the latest version
$manifest = Invoke-WebRequest -Uri $manifestPresigned.url -Headers @{ "Accept" = "application/octet-stream" } | Select-Object -ExpandProperty Content
$manifest = [System.Text.Encoding]::UTF8.GetString($manifest)
$version = $manifest -replace "currentVersion: ", "" # Extract the version
$version = $version -replace "`n", "" # Remove newlines
$versionNoV = $version -replace "v", "" # Remove the 'v' prefix

# --> Download 3rd party notices
# Get presigned URL for the 3rd party notices
$noticesUrl = "$nextmvBaseUrl/v0/internal/tools?file=cli/$($version)/third-party-notices.txt"
$noticesPresigned = Invoke-WebRequest -Uri $noticesUrl -Headers @{ "Authorization" = "Bearer $env:NEXTMV_API_KEY" } | ConvertFrom-Json
if (-not $noticesPresigned.url) {
    Write-Error "Failed to download 3rd party notices."
    return
}
# Download the 3rd party notices
$noticesPath = "$nextmvDir\third-party-notices.txt"
Invoke-WebRequest -Uri $noticesPresigned.url -OutFile $noticesPath

# --> Download the CLI
# Get presigned URL for the CLI
Write-Host "Downloading version $version..."
$cliUrl = "$nextmvBaseUrl/v0/internal/tools?file=cli/$($version)/nextmv_$($versionNoV)_windows_$($arch).tar.gz"
$cliPresigned = Invoke-WebRequest -Uri $cliUrl -Headers @{ "Authorization" = "Bearer $env:NEXTMV_API_KEY" } | ConvertFrom-Json
if (-not $cliPresigned.url) {
    Write-Error "Failed to download Nextmv CLI."
    return
}
# Download the CLI
$outPath = "$nextmvDir\nextmv.tar.gz"
Invoke-WebRequest -Uri $cliPresigned.url -OutFile $outPath


# --> Extract the CLI
Write-Host "Extracting..."
tar -xzf $outPath -C $nextmvDir
Remove-Item "$nextmvDir\nextmv.tar.gz"

# --> Add the CLI to the PATH
# Exit if PATH is already updated
if ($env:Path.Contains($nextmvDir)) {
    Write-Host "Nextmv CLI installed successfully."
    return
}

# Ask for elevated permissions to add the CLI to the PATH
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Please re-run this script as an Administrator to add the Nextmv CLI to the PATH."
    Write-Host "Or, you can manually add the Nextmv CLI to the PATH by adding the following directory to the PATH: $nextmvDir"
    return
}

# Add the CLI to the PATH (if not already added)
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine) + ";$nextmvDir"
if ($env:Path.Contains($nextmvDir)) {
    Write-Host "Adding Nextmv CLI to the PATH..."
    [Environment]::SetEnvironmentVariable("Path", $env:Path, [System.EnvironmentVariableTarget]::Machine)
}

# Confirm the installation
if (Test-Path $cliPath) {
    Write-Host "Nextmv CLI installed successfully."
}
else {
    Write-Error "Failed to install Nextmv CLI to the PATH."
}
