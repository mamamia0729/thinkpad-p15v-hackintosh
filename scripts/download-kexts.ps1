# Download all kexts and OpenCore for ThinkPad P15v Gen 1 Hackintosh build
# Requires: gh CLI (authenticated)
$ErrorActionPreference = "Stop"

$ProjectDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not $ProjectDir) { $ProjectDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }
$KextDir = Join-Path $ProjectDir "staging\kexts"
$OcDir = Join-Path $ProjectDir "staging\opencore"

# Verify gh is available and authenticated
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "[!] gh CLI not found. Install from https://cli.github.com" -ForegroundColor Red
    exit 1
}

$authCheck = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[!] gh CLI not authenticated. Run: gh auth login" -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Path $KextDir -Force | Out-Null
New-Item -ItemType Directory -Path $OcDir -Force | Out-Null

$FailCount = 0

function Download-Latest {
    param(
        [string]$Repo,
        [string]$Pattern,
        [string]$Dest
    )
    $Name = ($Repo -split "/")[-1]
    Write-Host "[*] $Name - fetching latest release..." -ForegroundColor Cyan

    $DestDir = Join-Path $Dest $Name
    New-Item -ItemType Directory -Path $DestDir -Force | Out-Null

    gh release download --repo $Repo --pattern $Pattern --dir $DestDir --clobber 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    OK Downloaded to $DestDir\" -ForegroundColor Green
        return $true
    } else {
        Write-Host "    FAILED: $Repo (pattern: $Pattern)" -ForegroundColor Red
        return $false
    }
}

Write-Host "======================================================" -ForegroundColor White
Write-Host "  Kext & OpenCore Downloader" -ForegroundColor White
Write-Host "  Target: macOS Sonoma 14.7 / ThinkPad P15v G1" -ForegroundColor White
Write-Host "======================================================" -ForegroundColor White
Write-Host ""

# OpenCore bootloader
Write-Host "-- OpenCore Bootloader --" -ForegroundColor Yellow
if (-not (Download-Latest "acidanthera/OpenCorePkg" "*-RELEASE.zip" $OcDir)) { $FailCount++ }
Write-Host ""

# Core kexts
Write-Host "-- Core Kexts --" -ForegroundColor Yellow
if (-not (Download-Latest "acidanthera/Lilu" "*-RELEASE.zip" $KextDir)) { $FailCount++ }
if (-not (Download-Latest "acidanthera/VirtualSMC" "*-RELEASE.zip" $KextDir)) { $FailCount++ }
if (-not (Download-Latest "acidanthera/WhateverGreen" "*-RELEASE.zip" $KextDir)) { $FailCount++ }
if (-not (Download-Latest "acidanthera/AppleALC" "*-RELEASE.zip" $KextDir)) { $FailCount++ }
if (-not (Download-Latest "acidanthera/NVMeFix" "*-RELEASE.zip" $KextDir)) { $FailCount++ }
Write-Host ""

# Networking
Write-Host "-- Networking --" -ForegroundColor Yellow
if (-not (Download-Latest "acidanthera/IntelMausi" "*-RELEASE.zip" $KextDir)) { $FailCount++ }
if (-not (Download-Latest "OpenIntelWireless/itlwm" "*.zip" $KextDir)) { $FailCount++ }
if (-not (Download-Latest "OpenIntelWireless/IntelBluetoothFirmware" "*.zip" $KextDir)) { $FailCount++ }
Write-Host ""

# Input
Write-Host "-- Input --" -ForegroundColor Yellow
if (-not (Download-Latest "VoodooI2C/VoodooI2C" "*.zip" $KextDir)) { $FailCount++ }
if (-not (Download-Latest "acidanthera/VoodooPS2" "*-RELEASE.zip" $KextDir)) { $FailCount++ }
Write-Host ""

# Laptop extras
Write-Host "-- Laptop Extras --" -ForegroundColor Yellow
if (-not (Download-Latest "1Revenger1/ECEnabler" "*.zip" $KextDir)) { $FailCount++ }
if (-not (Download-Latest "USBToolBox/kext" "*.zip" $KextDir)) { $FailCount++ }
if (-not (Download-Latest "USBToolBox/tool" "*.zip" $KextDir)) { $FailCount++ }
Write-Host ""

# Summary
Write-Host "======================================================" -ForegroundColor White
if ($FailCount -eq 0) {
    Write-Host "  OK All downloads complete!" -ForegroundColor Green
} else {
    Write-Host "  WARNING: $FailCount download(s) failed - check output above" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "  Kexts:    $KextDir\" -ForegroundColor White
Write-Host "  OpenCore: $OcDir\" -ForegroundColor White
Write-Host "======================================================" -ForegroundColor White
Write-Host ""

# List what we got
Write-Host "-- Downloaded Files --" -ForegroundColor Yellow
Get-ChildItem -Path $KextDir, $OcDir -Recurse -Filter "*.zip" |
    Select-Object @{N="File";E={$_.FullName.Replace($ProjectDir, ".")}}, @{N="Size";E={"{0:N0} KB" -f ($_.Length / 1KB)}} |
    Format-Table -AutoSize

Write-Host "Next: Unzip these into the EFI folder structure in Stage 3."
