# Hackintosh Walkthrough: ThinkPad P15v Gen 1

A step-by-step guide for installing macOS Sonoma 14.7 on a Lenovo ThinkPad P15v Gen 1. Written so that someone with basic computer skills can follow along.

> **What is a Hackintosh?** It's macOS (Apple's operating system) running on non-Apple hardware. Apple only supports macOS on their own Mac computers, but with the right tools and configuration, it can run on compatible PCs and laptops.

---

## Table of Contents

1. [What You Need Before Starting](#1-what-you-need-before-starting)
2. [Stage 1: BIOS Settings](#2-stage-1-bios-settings)
3. [Stage 2: Download the macOS Installer](#3-stage-2-download-the-macos-installer)
4. [Stage 3: Download Kexts and Build the EFI](#4-stage-3-download-kexts-and-build-the-efi)
5. [Stage 4: Prepare the USB Installer](#5-stage-4-prepare-the-usb-installer)
6. [Stage 5: Install macOS](#6-stage-5-install-macos)
7. [Stage 6: First Boot from Internal Disk](#7-stage-6-first-boot-from-internal-disk)
8. [Stage 7: Post-Install Polish](#8-stage-7-post-install-polish)
9. [Stage 8: Validate Apple Services](#9-stage-8-validate-apple-services)
10. [Troubleshooting](#10-troubleshooting)
11. [Glossary](#11-glossary)

---

## 1. What You Need Before Starting

### Hardware

- **Lenovo ThinkPad P15v Gen 1** (model 20TRS00T00 or similar with the same CPU/iGPU)
- **USB flash drive**, 16 GB or larger
- **A second computer** (Windows or Linux) to prepare the USB drive
- **Ethernet cable** (recommended for the install - Wi-Fi works but Ethernet is more reliable during setup)

### Software (on your second computer)

- **Python 3** - download from [python.org](https://www.python.org/downloads/) if you don't have it
- **Git** - download from [git-scm.com](https://git-scm.com/downloads)
- **GitHub CLI (gh)** - download from [cli.github.com](https://cli.github.com). After installing, run `gh auth login` to sign in

### Knowledge Check

You don't need to be a programmer, but you should be comfortable with:

- Opening a terminal (PowerShell on Windows, Terminal on Mac/Linux)
- Typing commands and pressing Enter
- Navigating your computer's BIOS setup (we'll walk you through this)

### Time Estimate

Expect 5-7 hours spread over a weekend. Each stage is a safe stopping point - you can take a break between any two stages.

---

## 2. Stage 1: BIOS Settings

The BIOS is the low-level software that runs before your operating system boots. We need to change some settings to make macOS happy.

### How to Enter BIOS

1. Shut down the ThinkPad completely
2. Press the power button
3. Immediately start tapping **F1** repeatedly until the BIOS screen appears
4. You'll see a blue/gray menu - use arrow keys to navigate, Enter to select

### Settings to Change

Go through each menu below and change the listed settings. If a setting isn't there, skip it - not all BIOS versions show every option.

#### Security Menu
| Setting | Change To | Why |
|---------|-----------|-----|
| Secure Boot | **Disabled** | macOS is not signed for PC Secure Boot. **This is the most important setting.** |
| Intel SGX | Disabled | Not supported by macOS |

#### Startup Menu
| Setting | Change To | Why |
|---------|-----------|-----|
| UEFI/Legacy Boot | **UEFI Only** | macOS only boots in UEFI mode |
| CSM Support | Disabled | Legacy compatibility we don't need |
| Fast Boot | Disabled | Can cause USB detection issues |

#### Config > CPU
| Setting | Change To | Why |
|---------|-----------|-----|
| Hyper-Threading | Enabled | More performance |
| VT-x (Virtualization) | Enabled | Required by macOS |
| VT-d | Enabled | OpenCore handles this safely |

#### Config > Power
| Setting | Change To | Why |
|---------|-----------|-----|
| Intel SpeedStep | Enabled | CPU power management |
| Sleep State | Linux or Windows 10 | Best sleep compatibility |

#### Config > Display (if present)
| Setting | Change To | Why |
|---------|-----------|-----|
| Graphics Device | Integrated Only (if available) | We're disabling the NVIDIA GPU for macOS |

### After Changing Settings

1. Press **F10** to Save and Exit
2. The laptop will reboot
3. **Write down** whether you found a "CFG Lock" toggle (Config > CPU or Security). This matters for Stage 3

---

## 3. Stage 2: Download the macOS Installer

We're downloading macOS directly from Apple's servers. No existing Mac is needed.

### Step by Step

1. **Clone this repository** (if you haven't already):
   ```
   git clone https://github.com/mamamia0729/thinkpad-p15v-hackintosh.git
   cd thinkpad-p15v-hackintosh
   ```

2. **Run the download script:**

   On **Windows (PowerShell)**:
   ```powershell
   .\scripts\download-installer.ps1
   ```

   On **Linux/Mac (Bash)**:
   ```bash
   bash scripts/download-installer.sh
   ```

3. **Wait for the download** - it's about 750 MB from Apple's CDN. Takes 5-15 minutes depending on your internet speed.

4. **Verify the download succeeded.** You should see two files in `staging/installer/sonoma-recovery/com.apple.recovery.boot/`:
   - `BaseSystem.dmg` (about 750 MB)
   - `BaseSystem.chunklist` (about 3 KB)

   If either file is missing or BaseSystem.dmg is under 700 MB, delete the folder and run the script again.

### What Just Happened?

The script used Apple's own `macrecovery.py` tool (from OpenCore) to download a macOS Sonoma recovery image. This is the same recovery system that real Macs use when you reinstall macOS over the internet. During Stage 5, this recovery image will download the full macOS from Apple's servers.

---

## 4. Stage 3: Download Kexts and Build the EFI

### What Are Kexts and EFI?

- **Kexts** (Kernel Extensions) are like drivers for macOS. Since Apple didn't design macOS for our ThinkPad, we need community-made kexts to make our hardware work (Wi-Fi, Bluetooth, trackpad, etc.)
- **EFI** (Extensible Firmware Interface) is a special partition on the USB drive where the bootloader (OpenCore) lives. OpenCore tricks macOS into thinking it's running on a real Mac

### Download All Kexts

1. **Make sure GitHub CLI is authenticated:**
   ```
   gh auth status
   ```
   If it says "not logged in", run `gh auth login` first.

2. **Run the kext download script:**

   On **Windows (PowerShell)**:
   ```powershell
   .\scripts\download-kexts.ps1
   ```

   On **Linux/Mac (Bash)**:
   ```bash
   bash scripts/download-kexts.sh
   ```

3. **Check the output.** It should say "All downloads complete!" and list every kext. If any show "FAILED", check your internet connection and run the script again.

### What Gets Downloaded

| Category | Kexts | Purpose |
|----------|-------|---------|
| Core | Lilu, VirtualSMC, WhateverGreen, AppleALC | Base patching, SMC emulation, GPU, audio |
| Networking | IntelMausi, AirportItlwm, IntelBluetoothFirmware | Ethernet, Wi-Fi, Bluetooth |
| Input | VoodooI2C, VoodooPS2Controller | Trackpad and keyboard |
| Laptop | ECEnabler, NVMeFix, USBToolBox | Battery, NVMe power, USB ports |
| Bootloader | OpenCore | The bootloader itself |

All files are saved to `staging/kexts/` and `staging/opencore/`.

---

## 5. Stage 4: Prepare the USB Installer

This stage assembles everything onto the USB drive.

### Format the USB Drive

> **WARNING:** This erases everything on the USB drive. Make sure you've backed up anything important on it.

#### On Windows (PowerShell as Administrator)

1. Open PowerShell **as Administrator** (right-click > Run as Administrator)
2. Find your USB disk number:
   ```powershell
   Get-Disk | Format-Table Number, FriendlyName, Size, BusType
   ```
   Look for the USB entry (BusType = USB). Note the **Number** (e.g., 2).

3. Wipe and format it (**replace `2` with your actual disk number**):
   ```powershell
   Clear-Disk -Number 2 -RemoveData -RemoveOEM -Confirm:$false
   Initialize-Disk -Number 2 -PartitionStyle GPT
   New-Partition -DiskNumber 2 -UseMaximumSize -AssignDriveLetter |
       Format-Volume -FileSystem FAT32 -NewFileSystemLabel "OCUSB"
   ```

4. Note which drive letter was assigned (e.g., E:)

### Build the EFI Folder Structure

Create these folders on the USB drive (replace `E:` with your drive letter):

```
E:\
├── EFI\
│   ├── BOOT\
│   └── OC\
│       ├── ACPI\
│       ├── Drivers\
│       ├── Kexts\
│       ├── Resources\
│       └── Tools\
└── com.apple.recovery.boot\
```

On PowerShell:
```powershell
$usb = "E:"
$dirs = @("EFI\BOOT","EFI\OC\ACPI","EFI\OC\Drivers","EFI\OC\Kexts",
          "EFI\OC\Resources","EFI\OC\Tools","com.apple.recovery.boot")
foreach ($d in $dirs) { New-Item -ItemType Directory -Path "$usb\$d" -Force }
```

### Copy OpenCore Bootloader Files

1. **Unzip** `staging/opencore/OpenCorePkg/OpenCore-*-RELEASE.zip`
2. From the unzipped `X64/EFI/` folder, copy:
   - `BOOT/BOOTx64.efi` → `E:\EFI\BOOT\BOOTx64.efi`
   - `OC/OpenCore.efi` → `E:\EFI\OC\OpenCore.efi`
   - `OC/Drivers/OpenRuntime.efi` → `E:\EFI\OC\Drivers\`
   - `OC/Drivers/OpenCanopy.efi` → `E:\EFI\OC\Drivers\`
   - `OC/Resources/*` → `E:\EFI\OC\Resources\` (icons for boot menu)
   - `OC/Tools/OpenShell.efi` → `E:\EFI\OC\Tools\`

3. **Download HfsPlus.efi** (Apple's HFS+ filesystem driver - required):
   ```
   curl -L "https://github.com/acidanthera/OcBinaryData/raw/master/Drivers/HfsPlus.efi" -o E:\EFI\OC\Drivers\HfsPlus.efi
   ```

### Copy Kexts

Extract each zip from `staging/kexts/` and copy the `.kext` folders to `E:\EFI\OC\Kexts\`.

**Important notes:**
- Only use the **RELEASE** versions (not DEBUG)
- For **AirportItlwm**, use the **Sonoma 14.4** version (matches our target macOS)
- Some kexts contain **plugins** inside them (e.g., VoodooPS2Controller.kext has VoodooPS2Keyboard.kext inside it). Don't copy the plugins separately - they stay nested inside the parent kext
- **Remove kexts you don't need:** SMCDellSensors (Dell only), SMCSuperIO (desktops), IntelSnowMausi (ancient), AppleALCU (digital-only audio), IntelBluetoothInjector (Catalina only)

Your final kext list should be:

```
AirportItlwm.kext           IntelBTPatcher.kext        SMCProcessor.kext
AppleALC.kext               IntelBluetoothFirmware.kext USBToolBox.kext
ECEnabler.kext              IntelMausi.kext            UTBDefault.kext
Lilu.kext                   NVMeFix.kext               VirtualSMC.kext
SMCBatteryManager.kext      VoodooI2C.kext             VoodooPS2Controller.kext
SMCLightSensor.kext         VoodooI2CHID.kext          WhateverGreen.kext
```

### Copy ACPI Tables (SSDTs)

Download these precompiled SSDTs and place them in `E:\EFI\OC\ACPI\`:

```
curl -L "https://github.com/dortania/Getting-Started-With-ACPI/raw/master/extra-files/compiled/SSDT-PLUG-DRTNIA.aml" -o E:\EFI\OC\ACPI\SSDT-PLUG.aml
curl -L "https://github.com/dortania/Getting-Started-With-ACPI/raw/master/extra-files/compiled/SSDT-EC-USBX-LAPTOP.aml" -o E:\EFI\OC\ACPI\SSDT-EC-USBX.aml
curl -L "https://github.com/dortania/Getting-Started-With-ACPI/raw/master/extra-files/compiled/SSDT-PNLF.aml" -o E:\EFI\OC\ACPI\SSDT-PNLF.aml
curl -L "https://github.com/dortania/Getting-Started-With-ACPI/raw/master/extra-files/compiled/SSDT-dGPU-Off.aml" -o E:\EFI\OC\ACPI\SSDT-DDGPU.aml
curl -L "https://github.com/dortania/Getting-Started-With-ACPI/raw/master/extra-files/compiled/SSDT-AWAC.aml" -o E:\EFI\OC\ACPI\SSDT-AWAC.aml
curl -L "https://github.com/dortania/Getting-Started-With-ACPI/raw/master/extra-files/compiled/SSDT-XOSI.aml" -o E:\EFI\OC\ACPI\SSDT-XOSI.aml
```

**What each SSDT does:**
| File | Purpose |
|------|---------|
| SSDT-PLUG.aml | Enables CPU power management (SpeedStep, turbo boost) |
| SSDT-EC-USBX.aml | Creates a fake Embedded Controller that macOS expects on laptops, plus USB power settings |
| SSDT-PNLF.aml | Enables screen brightness controls |
| SSDT-DDGPU.aml | Disables the NVIDIA Quadro P620 (macOS has no driver for it) |
| SSDT-AWAC.aml | Fixes the system clock so macOS can read the time correctly |
| SSDT-XOSI.aml | Tells the ThinkPad firmware to behave as if running Windows, which enables the I2C trackpad |

### Copy macOS Recovery Files

Copy the two files from Stage 2 into the USB:

```
copy staging\installer\sonoma-recovery\com.apple.recovery.boot\BaseSystem.dmg E:\com.apple.recovery.boot\
copy staging\installer\sonoma-recovery\com.apple.recovery.boot\BaseSystem.chunklist E:\com.apple.recovery.boot\
```

### Set Up config.plist

The `config.plist` is the master configuration file for OpenCore. It tells the bootloader how to handle your specific hardware. A pre-built config.plist for this ThinkPad model is included in this repo at `EFI/OC/config.plist`.

1. Copy it to the USB:
   ```
   copy EFI\OC\config.plist E:\EFI\OC\config.plist
   ```

2. **IMPORTANT: Generate Unique SMBIOS Values**

   macOS needs to think it's running on a real Mac. Each real Mac has a unique serial number, and you need to generate fake-but-valid ones for your Hackintosh. **Without this step, iCloud and iMessage will not work.**

   a. Extract `macserial.exe` from the OpenCore zip (`Utilities/macserial/macserial.exe`)

   b. Generate a serial number pair:
      ```
      macserial.exe -m MacBookPro16,1 -g -n 1
      ```
      This outputs two values separated by `|`:
      - First value = **SystemSerialNumber** (e.g., `C02XXXXXXXXX`)
      - Second value = **MLB** / Board Serial (e.g., `C02XXXXXXXXXX`)

   c. Generate a UUID (PowerShell):
      ```powershell
      [guid]::NewGuid().ToString().ToUpper()
      ```

   d. Generate a ROM value (PowerShell):
      ```powershell
      -join ((1..6) | ForEach-Object { '{0:X2}' -f (Get-Random -Maximum 256) })
      ```

   e. Open `E:\EFI\OC\config.plist` in a text editor and find/replace these four placeholder values under `PlatformInfo > Generic`:
      - Replace `CHANGE_ME_USE_GenSMBIOS` next to `SystemSerialNumber` with your generated serial
      - Replace `CHANGE_ME_USE_GenSMBIOS` next to `MLB` with your generated board serial
      - Replace `CHANGE_ME_USE_GenSMBIOS` next to `SystemUUID` with your generated UUID
      - The `ROM` field needs to be set to your 6-byte hex value (base64 encoded in the plist)

   f. **Save these values somewhere safe** (e.g., `SMBIOS_VALUES.txt`). If you ever need to reinstall, you'll want the same values to keep your iCloud account linked.

### Validate Your Config

Extract `ocvalidate.exe` from the OpenCore zip (`Utilities/ocvalidate/ocvalidate.exe`) and run:

```
ocvalidate.exe E:\EFI\OC\config.plist
```

You should see: `No issues found.`

If you see errors, check [OCVALIDATE-FIXES.md](OCVALIDATE-FIXES.md) for solutions.

---

## 6. Stage 5: Install macOS

> **WARNING: This stage wipes the ThinkPad's internal NVMe drive. Back up everything first. This cannot be undone.**

### Boot from USB

1. Plug the USB drive into the ThinkPad
2. Power on and press **F12** at the Lenovo splash screen to open the boot menu
3. Select your USB drive (it may show as "EFI USB Device" or "UEFI: [your USB name]")
4. You should see the **OpenCore boot picker** - a graphical menu with icons
5. Select **"macOS Base System"** (or the recovery option)

### What to Expect

- The screen will fill with white text on a black background (verbose boot). This is normal - it's macOS loading with debug output enabled
- First boot takes 2-5 minutes. Be patient
- If you see a line that says `End SetPowerState` and nothing happens for 30+ seconds, that's usually fine - wait up to 5 minutes
- If the screen goes black and the laptop reboots, see [Troubleshooting](#10-troubleshooting)

### Install macOS

1. When the recovery screen loads, you'll see **macOS Utilities**
2. First, open **Disk Utility**:
   - Click **View > Show All Devices** (top-left)
   - Select your internal NVMe drive (the physical disk, not a partition)
   - Click **Erase**
   - Name: `Macintosh HD`
   - Format: **APFS**
   - Scheme: **GUID Partition Map**
   - Click Erase
3. Close Disk Utility
4. Click **Reinstall macOS Sonoma**
5. Follow the prompts, select `Macintosh HD` as the destination
6. The install will download the full macOS from Apple (~12 GB) and install it
7. **The laptop will reboot 2-3 times during install.** Each time, boot from the USB again and select `Macintosh HD` (not "macOS Base System") from the OpenCore picker
8. When you see the macOS setup assistant (choose your language, etc.), the install is complete

---

## 7. Stage 6: First Boot from Internal Disk

macOS is installed, but it can only boot via the USB drive. We need to copy the EFI to the internal disk.

### Copy EFI to Internal NVMe

1. Boot into macOS using the USB drive
2. Open **Terminal** (Applications > Utilities > Terminal)
3. Find the internal disk's EFI partition:
   ```bash
   diskutil list
   ```
   Look for the internal NVMe (usually `disk0`). Note its EFI partition identifier (e.g., `disk0s1`)

4. Mount the internal EFI partition:
   ```bash
   sudo mkdir -p /Volumes/InternalEFI
   sudo mount -t msdos /dev/disk0s1 /Volumes/InternalEFI
   ```

5. Mount the USB's EFI partition:
   ```bash
   sudo mkdir -p /Volumes/USBEFI
   sudo mount -t msdos /dev/disk2s1 /Volumes/USBEFI
   ```
   (Your USB disk number may differ - check `diskutil list`)

6. Copy the EFI folder:
   ```bash
   sudo cp -R /Volumes/USBEFI/EFI /Volumes/InternalEFI/
   ```

7. **Reboot, remove the USB, and boot normally.** The ThinkPad should now boot macOS from the internal drive via OpenCore.

---

## 8. Stage 7: Post-Install Polish

After macOS is running from the internal drive, test and fine-tune:

### Checklist

| Feature | Expected | If Not Working |
|---------|----------|----------------|
| Keyboard | Works out of box | Check VoodooPS2Controller.kext is loaded |
| Trackpad | Multitouch gestures | Check VoodooI2C + VoodooI2CHID. SSDT-XOSI must be present |
| TrackPoint | Red nub mouse | Handled by VoodooPS2Mouse plugin |
| Screen brightness | Fn+F5/F6 | Check SSDT-PNLF.aml is in ACPI folder |
| Audio | Speakers + headphone jack | Check AppleALC.kext and `alcid=17` in boot-args |
| Wi-Fi | Connects to networks | AirportItlwm - may need to forget and rejoin networks |
| Bluetooth | Pairs devices | IntelBluetoothFirmware.kext |
| Ethernet | Works immediately | IntelMausi.kext |
| Battery | Shows percentage | SMCBatteryManager + ECEnabler |
| Sleep | Lid close/open | May need BIOS sleep state = Linux. Test thoroughly |
| USB ports | All ports work | If some ports don't work, run USBToolBox mapping tool |
| Camera | Works in FaceTime | Native UVC driver, should work automatically |

### Removing Verbose Boot

Once everything is stable, you can remove the debug text that shows on every boot:

1. Mount the EFI partition (same process as Stage 6)
2. Open `EFI/OC/config.plist` in a text editor
3. Find the `boot-args` line and remove `-v` from the string
4. Save and reboot - you'll now see a clean Apple logo during boot

---

## 9. Stage 8: Validate Apple Services

### iCloud

1. Open **System Settings > Apple ID**
2. Sign in with your Apple ID
3. If it says "This Mac is not supported" or asks for a phone number verification, your SMBIOS serial may be flagged. Generate a new set and try again

### iMessage and FaceTime

1. Open **Messages** and sign in
2. Open **FaceTime** and sign in
3. If sign-in fails, it usually means:
   - Your serial number matches a real Mac that's already registered (generate new ones)
   - You need to call Apple support to "activate" iMessage on this device (rare)

### App Store

1. Open the **App Store** and try downloading a free app
2. This should work if iCloud sign-in succeeded

### What Won't Work (Expected)

- **AirDrop, Handoff, Universal Clipboard** - requires a Broadcom Wi-Fi card, which we can't swap (Intel AX201 is soldered into the chipset)
- **Fingerprint reader** - no macOS driver exists
- **SD card reader** - no macOS driver exists
- **Apple Watch unlock** - same limitation as AirDrop

---

## 10. Troubleshooting

### Laptop reboots immediately after selecting macOS Base System

- **Most common cause:** Wrong `ig-platform-id` or missing WhateverGreen.kext
- Verify `config.plist` has `AAPL,ig-platform-id` set to `00009B3E`
- Make sure WhateverGreen.kext and Lilu.kext are both in `EFI/OC/Kexts/` AND listed in `config.plist`

### Stuck at `[EB|#LOG:EXITBS:START]`

- Usually a GPU issue. Verify SSDT-DDGPU.aml is disabling the NVIDIA GPU
- Try adding `igfxonln=1` to boot-args

### No audio

- Try different `alcid` values in boot-args: `alcid=11`, `alcid=17`, `alcid=18`, `alcid=86`
- Layout 17 is confirmed for ALC257 on this model

### Trackpad not working

- Verify SSDT-XOSI.aml is in `EFI/OC/ACPI/` and listed in config.plist
- Verify the `_OSI to XOSI` rename patch is enabled in config.plist under `ACPI > Patch`
- Verify both VoodooI2C.kext and VoodooI2CHID.kext are loaded

### Wi-Fi not connecting

- AirportItlwm can be slow to scan. Wait 30 seconds after boot
- If networks don't appear, try `itlwm.kext` instead of `AirportItlwm.kext` (requires HeliPort app for Wi-Fi management)

### ocvalidate shows errors

- See [OCVALIDATE-FIXES.md](OCVALIDATE-FIXES.md) for a complete list of errors we encountered on OpenCore 1.0.7 and how to fix each one

---

## 11. Glossary

| Term | Meaning |
|------|---------|
| **BIOS** | Basic Input/Output System - firmware that runs before your OS. On modern laptops, technically UEFI firmware |
| **UEFI** | Unified Extensible Firmware Interface - the modern replacement for BIOS |
| **EFI partition** | A small FAT32 partition on your disk where the bootloader lives |
| **OpenCore** | The bootloader that makes macOS think your PC is a real Mac |
| **Kext** | Kernel Extension - macOS equivalent of a driver |
| **SSDT** | Secondary System Description Table - ACPI code that patches your laptop's hardware tables for macOS compatibility |
| **ACPI** | Advanced Configuration and Power Interface - how the OS talks to hardware |
| **config.plist** | OpenCore's master configuration file (XML format) |
| **SMBIOS** | System Management BIOS - the identity we assign to make macOS think this is a MacBookPro16,1 |
| **iGPU** | Integrated GPU - the Intel UHD P630 built into the CPU |
| **dGPU** | Discrete GPU - the NVIDIA Quadro P620 (separate chip, disabled for macOS) |
| **Device-ID spoof** | Telling macOS that our UHD P630 is actually a UHD 630, so it loads the right driver |
| **CNVi** | Connectivity Integration - Intel's way of building Wi-Fi into the chipset, meaning the card can't be physically swapped |
| **GenSMBIOS** | A tool to generate fake-but-valid Apple serial numbers |
| **ocvalidate** | OpenCore's built-in config validation tool |
| **Verbose boot** | The `-v` flag that shows all boot messages as text instead of the Apple logo |

---

## Credits

- **Author:** Thinh Le
- [Dortania OpenCore Install Guide](https://dortania.github.io/OpenCore-Install-Guide) - the definitive Hackintosh resource
- [OpenIntelWireless](https://openintelwireless.github.io) - Intel Wi-Fi and Bluetooth for macOS
- [Acidanthera](https://github.com/acidanthera) - OpenCore, Lilu, VirtualSMC, WhateverGreen, AppleALC, and more
- [ivan19871002/Thinkpad-P15V-Gen1-Hackintosh](https://github.com/ivan19871002/Thinkpad-P15V-Gen1-Hackintosh) - reference build for this model
