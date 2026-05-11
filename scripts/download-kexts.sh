#!/usr/bin/env bash
# Download all kexts and OpenCore for ThinkPad P15v Gen 1 Hackintosh build
# Requires: gh CLI (authenticated)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
KEXT_DIR="$PROJECT_DIR/staging/kexts"
OC_DIR="$PROJECT_DIR/staging/opencore"

# Verify gh is available and authenticated
if ! command -v gh &>/dev/null; then
    echo "[!] gh CLI not found. Install from https://cli.github.com"
    exit 1
fi

if ! gh auth status &>/dev/null 2>&1; then
    echo "[!] gh CLI not authenticated. Run: gh auth login"
    exit 1
fi

mkdir -p "$KEXT_DIR" "$OC_DIR"

# ── Helper: download latest release asset matching a pattern ──
download_latest() {
    local repo="$1"
    local pattern="$2"
    local dest="$3"
    local name
    name=$(basename "$repo")

    echo "[*] $name - fetching latest release..."
    mkdir -p "$dest/$name"

    if gh release download --repo "$repo" --pattern "$pattern" --dir "$dest/$name" --clobber 2>/dev/null; then
        echo "    ✓ Downloaded to $dest/$name/"
    else
        echo "    ✗ FAILED: $repo (pattern: $pattern)"
        return 1
    fi
}

echo "═══════════════════════════════════════════════"
echo "  Kext & OpenCore Downloader"
echo "  Target: macOS Sonoma 14.7 / ThinkPad P15v G1"
echo "═══════════════════════════════════════════════"
echo ""

FAIL_COUNT=0

# ── OpenCore bootloader ──
echo "── OpenCore Bootloader ──"
download_latest "acidanthera/OpenCorePkg" "*-RELEASE.zip" "$OC_DIR" || ((FAIL_COUNT++))
echo ""

# ── Core kexts (Acidanthera) ──
echo "── Core Kexts ──"
download_latest "acidanthera/Lilu" "*-RELEASE.zip" "$KEXT_DIR" || ((FAIL_COUNT++))
download_latest "acidanthera/VirtualSMC" "*-RELEASE.zip" "$KEXT_DIR" || ((FAIL_COUNT++))
download_latest "acidanthera/WhateverGreen" "*-RELEASE.zip" "$KEXT_DIR" || ((FAIL_COUNT++))
download_latest "acidanthera/AppleALC" "*-RELEASE.zip" "$KEXT_DIR" || ((FAIL_COUNT++))
download_latest "acidanthera/NVMeFix" "*-RELEASE.zip" "$KEXT_DIR" || ((FAIL_COUNT++))
echo ""

# ── Networking ──
echo "── Networking ──"
download_latest "acidanthera/IntelMausi" "*-RELEASE.zip" "$KEXT_DIR" || ((FAIL_COUNT++))
download_latest "OpenIntelWireless/itlwm" "*.zip" "$KEXT_DIR" || ((FAIL_COUNT++))
download_latest "OpenIntelWireless/IntelBluetoothFirmware" "*.zip" "$KEXT_DIR" || ((FAIL_COUNT++))
echo ""

# ── Input ──
echo "── Input ──"
download_latest "VoodooI2C/VoodooI2C" "*.zip" "$KEXT_DIR" || ((FAIL_COUNT++))
download_latest "acidanthera/VoodooPS2" "*-RELEASE.zip" "$KEXT_DIR" || ((FAIL_COUNT++))
echo ""

# ── Laptop extras ──
echo "── Laptop Extras ──"
download_latest "1Revenger1/ECEnabler" "*.zip" "$KEXT_DIR" || ((FAIL_COUNT++))
download_latest "USBToolBox/kext" "*.zip" "$KEXT_DIR" || ((FAIL_COUNT++))
download_latest "USBToolBox/tool" "*.zip" "$KEXT_DIR" || ((FAIL_COUNT++))
echo ""

# ── Summary ──
echo "═══════════════════════════════════════════════"
if [ "$FAIL_COUNT" -eq 0 ]; then
    echo "  ✓ All downloads complete!"
else
    echo "  ⚠ $FAIL_COUNT download(s) failed - check output above"
fi
echo ""
echo "  Kexts:    $KEXT_DIR/"
echo "  OpenCore: $OC_DIR/"
echo "═══════════════════════════════════════════════"
echo ""

# List what we got
echo "── Downloaded Files ──"
find "$KEXT_DIR" -name "*.zip" -printf "  %p (%s bytes)\n" 2>/dev/null || \
    find "$KEXT_DIR" -name "*.zip" -exec ls -lh {} \; 2>/dev/null
find "$OC_DIR" -name "*.zip" -printf "  %p (%s bytes)\n" 2>/dev/null || \
    find "$OC_DIR" -name "*.zip" -exec ls -lh {} \; 2>/dev/null

echo ""
echo "Next: Unzip these into the EFI folder structure in Stage 3."
