# Download macOS Sonoma 14.7 recovery installer via macrecovery.py
# Run from Windows with Python 3 installed. No Mac required.
$ErrorActionPreference = "Stop"

$ProjectDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not $ProjectDir) { $ProjectDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }
$WorkDir = Join-Path $ProjectDir "staging\installer"
$MacrecoveryDir = Join-Path $WorkDir "OpenCorePkg"

New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null

# Clone OpenCorePkg (only need macrecovery.py from it)
if (Test-Path $MacrecoveryDir) {
    Write-Host "[*] OpenCorePkg already cloned, pulling latest..." -ForegroundColor Cyan
    git -C $MacrecoveryDir pull --quiet
} else {
    Write-Host "[*] Cloning OpenCorePkg for macrecovery.py..." -ForegroundColor Cyan
    git clone --depth 1 https://github.com/acidanthera/OpenCorePkg.git $MacrecoveryDir
}

$Macrecovery = Join-Path $MacrecoveryDir "Utilities\macrecovery\macrecovery.py"

if (-not (Test-Path $Macrecovery)) {
    Write-Host "[!] macrecovery.py not found at $Macrecovery" -ForegroundColor Red
    exit 1
}

# Detect python
$Python = $null
foreach ($cmd in @("python3", "python")) {
    if (Get-Command $cmd -ErrorAction SilentlyContinue) {
        $Python = $cmd
        break
    }
}

if (-not $Python) {
    Write-Host "[!] Python 3 not found. Install Python 3 and retry." -ForegroundColor Red
    exit 1
}

Write-Host "[*] Using: $(& $Python --version)" -ForegroundColor Cyan

# Download macOS Sonoma recovery image
$OutputDir = Join-Path $WorkDir "sonoma-recovery"
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

Write-Host "[*] Downloading macOS Sonoma recovery to: $OutputDir" -ForegroundColor Cyan
Write-Host "[*] This will download ~700MB from Apple CDN..." -ForegroundColor Yellow
Write-Host ""

Push-Location $OutputDir
try {
    & $Python $Macrecovery -b Mac-827FAC58A8FDFA22 -m 00000000000000000 -os latest download
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "[OK] Download complete. Files in: $OutputDir" -ForegroundColor Green
Write-Host ""
Write-Host "Expected files:"
Write-Host "  - BaseSystem.dmg (or RecoveryImage.dmg)"
Write-Host "  - BaseSystem.chunklist (or RecoveryImage.chunklist)"
Write-Host ""
Write-Host "These will be copied to the USB installer in Stage 4."
Get-ChildItem $OutputDir | Format-Table Name, Length -AutoSize
