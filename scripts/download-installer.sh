#!/usr/bin/env bash
# Download macOS Sonoma 14.7 recovery installer via macrecovery.py
# Run from any OS with Python 3 installed. No Mac required.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
WORK_DIR="$PROJECT_DIR/staging/installer"
MACRECOVERY_DIR="$WORK_DIR/OpenCorePkg"

mkdir -p "$WORK_DIR"

# Clone OpenCorePkg (only need macrecovery.py from it)
if [ -d "$MACRECOVERY_DIR" ]; then
    echo "[*] OpenCorePkg already cloned, pulling latest..."
    git -C "$MACRECOVERY_DIR" pull --quiet
else
    echo "[*] Cloning OpenCorePkg for macrecovery.py..."
    git clone --depth 1 https://github.com/acidanthera/OpenCorePkg.git "$MACRECOVERY_DIR"
fi

MACRECOVERY="$MACRECOVERY_DIR/Utilities/macrecovery/macrecovery.py"

if [ ! -f "$MACRECOVERY" ]; then
    echo "[!] macrecovery.py not found at $MACRECOVERY"
    exit 1
fi

# Detect python
PYTHON=""
for cmd in python3 python; do
    if command -v "$cmd" &>/dev/null; then
        PYTHON="$cmd"
        break
    fi
done

if [ -z "$PYTHON" ]; then
    echo "[!] Python 3 not found. Install Python 3 and retry."
    exit 1
fi

echo "[*] Using: $($PYTHON --version)"

# Download macOS Sonoma recovery image
# Board ID Mac-827FAC58A8FDFA22 = iMacPro1,1, used by Dortania for Sonoma recovery
OUTPUT_DIR="$WORK_DIR/sonoma-recovery"
mkdir -p "$OUTPUT_DIR"

echo "[*] Downloading macOS Sonoma recovery to: $OUTPUT_DIR"
echo "[*] This will download ~700MB from Apple CDN..."
echo ""

cd "$OUTPUT_DIR"
"$PYTHON" "$MACRECOVERY" \
    -b Mac-827FAC58A8FDFA22 \
    -m 00000000000000000 \
    -os latest \
    download

echo ""
echo "[✓] Download complete. Files in: $OUTPUT_DIR"
echo ""
echo "Expected files:"
echo "  - BaseSystem.dmg (or RecoveryImage.dmg)"
echo "  - BaseSystem.chunklist (or RecoveryImage.chunklist)"
echo ""
echo "These will be copied to the USB installer in Stage 4."
ls -lh "$OUTPUT_DIR"
