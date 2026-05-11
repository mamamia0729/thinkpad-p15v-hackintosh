# ThinkPad P15v Gen 1 Hackintosh Build

End-of-life Intel Hackintosh project on Lenovo ThinkPad P15v Gen 1 (20TRS00T00), targeting macOS Sonoma 14.7 as a macOS-only build.

## Context: Why Hackintosh in 2026

Apple confirmed at WWDC 2025 that macOS Tahoe 26 is the LAST major macOS release supporting Intel Macs. macOS 27 (expected late 2026) will be Apple Silicon only.

Timeline:
- Full macOS support for Intel: through September 2026
- Apple security updates for last Intel Macs: through ~2028
- Hackintosh community already running Tahoe 26 on supported hardware
- After 2028, frozen OS

This build is a deliberate "last hurrah" project to gain ~2 years of useful macOS on hardware already owned.

## Hardware Evaluation: The Pile

Four machines evaluated for Hackintosh viability:

| Machine | CPU Gen | iGPU | dGPU | Verdict |
|---------|---------|------|------|---------|
| HP Pro Mini 400 G9 | 13th (i7-13700T) | UHD 770 (unsupported) | None, no PCIe slot | Hard NO |
| HP ZBook Studio G10 | 13th (i7/i9-13xxxH) | Iris Xe (unsupported) | NVIDIA RTX (unsupported) | Hard NO |
| HP ZBook Fury 16 G9 | 12th (Alder Lake-HX) | UHD (unsupported) | NVIDIA RTX = NO, AMD W6600M = MAYBE | Conditional |
| ThinkPad P15v Gen 1 | 10th (Xeon W-10855M) | UHD P630 (supported) | NVIDIA P620 (disable via SSDT) | STRONG YES |

### Why 13th gen and newer fail
- Intel iGPU drivers stopped at 10th gen (UHD 630 family) in macOS
- 11th gen Iris Xe, 12th gen UHD on Alder Lake-HX, 13th gen UHD 770: all unsupported
- NVIDIA Pascal/Turing/Ampere/Ada: dead in macOS since macOS Mojave (no web drivers post-10.13)
- AMD RDNA2 (W6600M, RX 6600 series) works with patches but is finicky

### Why ThinkPad P15v Gen 1 wins
- 10th gen Comet Lake CPU: last fully-supported Intel generation for macOS
- UHD P630 iGPU: workstation variant of UHD 630, needs only device-id spoof
- NVIDIA Quadro P620: disabled cleanly via SSDT-DDGPU hotpatch
- Existing community reference build: `ivan19871002/Thinkpad-P15V-Gen1-Hackintosh` (macOS Ventura 13.2 confirmed working)

## Target Machine: Full Hardware Inventory

System: Lenovo ThinkPad P15v Gen 1
Model: 20TRS00T00
Serial: PF2LYPFA
BIOS: N30ET61W (1.97), 2025-09-18
Mode: UEFI

| Component | Device ID | macOS Path |
|-----------|-----------|------------|
| CPU Xeon W-10855M (Comet Lake, 6c/12t) | Family 6 Model 165 Stepping 2 | Native, SMBIOS MacBookPro16,1 |
| iGPU UHD P630 | [8086:9bf6] | Device-id spoof to UHD 630 [8086:9bc5] |
| dGPU NVIDIA Quadro P620 | [10de:1cbd] | SSDT-DDGPU.aml to disable |
| Wi-Fi Intel AX201 CNVi | [8086:06f0] | OpenIntelWireless (itlwm + AirportItlwm) |
| Bluetooth Intel AX201 | USB [8087:0026] | IntelBluetoothFirmware |
| Audio Realtek ALC257 via Comet Lake cAVS | [8086:06c8] | AppleALC.kext, layout-id 17 |
| Ethernet Intel I219-LM | [8086:0d4c] | IntelMausi.kext (native) |
| NVMe SK hynix PC611 | [1c5c:1639] | Native, no NVMeFix needed |
| Camera Bison UVC | USB [5986:9106] | Native UVC |
| Trackpad Synaptics I2C | I2C bus | VoodooI2C + VoodooI2CHID |
| Fingerprint reader | USB [06cb:00bd] | No driver, accept loss |
| SD Card Reader RTS525A | [10ec:525a] | No driver, accept loss |
| Thunderbolt JHL7540 (Titan Ridge) | [8086:15e7] | Disable or USB-C only |
| RAM | 32GB DDR4-3200 (single-channel, BANK 2) | Native |

## Decisions Locked In

| Decision | Choice | Rationale |
|----------|--------|-----------|
| macOS version | Sonoma 14.7.x | Most stable Comet Lake support, mature kexts, security updates through 2026 |
| SMBIOS | MacBookPro16,1 | 16" 2019 MBP with i7-9750H 6c/12t Coffee Lake = closest match to Xeon W-10855M |
| Wi-Fi | OpenIntelWireless, no card swap | AX201 is CNVi (integrated into PCH), AirDrop/Continuity not needed |
| Audio | AppleALC + ALC257 layout-id 17 | Matches reference build |
| dGPU | Disable NVIDIA P620 via SSDT-DDGPU.aml | Pascal architecture dead in modern macOS, iGPU drives everything |
| Disk layout | Single OS, full disk macOS, wipe Ubuntu | Cleanest path, no dual-boot EFI complexity |
| Storage target | SK hynix PC611 1TB NVMe (internal) | Single drive, full disk |

## Accepted Feature Losses

The following will NOT work in this build. Accepted as part of the design tradeoff:

- AirDrop, Handoff, Universal Clipboard, Sidecar, Apple Watch unlock (Wi-Fi card limitation)
- Fingerprint reader (no macOS driver)
- SD card reader (no macOS driver)
- Reliable Thunderbolt 3 hot-plug for displays (community-wide known issue)

What WILL work: iCloud, iMessage, FaceTime, App Store, Camera, Audio, Sleep, Ethernet, Wi-Fi (functional, just no Continuity), Bluetooth, full GPU acceleration via iGPU, Trackpad multitouch, Brightness, Battery percentage.

## The 8-Stage Build Roadmap

```
Stage 1: BIOS Settings              <- CURRENT
Stage 2: Download macOS Installer
Stage 3: Build OpenCore EFI
Stage 4: Write Installer to USB
Stage 5: Boot Installer + Wipe NVMe + Install macOS
Stage 6: First Boot + Copy EFI to Internal Disk
Stage 7: Post-Install Kexts + Polish (trackpad, audio, sleep)
Stage 8: Validate iCloud, iMessage, App Store
```

Estimated 10 to 14 Pomodoros total, spread over 2 weekends. Stage boundaries are safe stopping points.

## Stage 1: BIOS Settings Checklist

Access: Reboot, press F1 at Lenovo splash.

### Security menu
- Secure Boot: Disabled (critical)
- Intel SGX: Disabled
- Intel TXT: Disabled (if present)
- Memory Protection: Disabled (if present)

### Startup menu
- UEFI/Legacy Boot: UEFI Only
- CSM Support: Disabled (if present)
- Fast Boot: Disabled

### Config menu
- USB UEFI BIOS Support: Enabled
- Thunderbolt BIOS Assist Mode: Disabled (if present)

### Config to CPU submenu
- Hyper-Threading: Enabled
- Virtualization (VT-x): Enabled
- VT-d Feature: Enabled (OpenCore handles via DisableIoMapper=true)

### Config to Power submenu
- Intel SpeedStep: Enabled
- CPU Power Management: Automatic
- Sleep State: Linux or Windows 10

### Config to Display submenu (if present)
- Graphics Device: Integrated Only if available (cleanest), else Hybrid
- Total Graphics Memory: 1024 MB if option exists

### Items to Report Back After Stage 1
1. Is there a CFG Lock toggle? (Config to CPU or Security menus)
2. Is there a Graphics Device selector that allows "Integrated Only"?
3. Confirm Secure Boot is now Disabled.
4. Confirm Ubuntu still boots normally after changes.

## Stage 2 Preview: macOS Installer Download

Will use OpenCore's `macrecovery.py` to download macOS Sonoma 14.7 installer files directly from Apple servers, running from Ubuntu. No Mac required to source the installer.

## Kext Shopping List (Stage 3 Prep)

To be downloaded fresh from each project's releases page at Stage 3:

- Lilu.kext (universal patcher base)
- VirtualSMC.kext + SMCBatteryManager + SMCLightSensor + SMCProcessor
- WhateverGreen.kext (iGPU patches)
- AppleALC.kext (audio)
- IntelMausi.kext (Ethernet)
- AirportItlwm.kext + itlwm.kext (Wi-Fi)
- IntelBluetoothFirmware.kext + IntelBTPatcher.kext (Bluetooth)
- VoodooI2C.kext + VoodooI2CHID.kext (trackpad)
- VoodooPS2Controller.kext (keyboard, TrackPoint)
- NVMeFix.kext (precautionary, may not be needed for SK hynix PC611)
- USBToolBox kit (USB port mapping at post-install)
- ECEnabler.kext (battery status on ThinkPads)

## Reference Resources

- Reference build (slightly different config, same model): https://github.com/ivan19871002/Thinkpad-P15V-Gen1-Hackintosh
- OpenCore Install Guide: https://dortania.github.io/OpenCore-Install-Guide
- OpenCore GPU Buyer Guide: https://dortania.github.io/GPU-Buyers-Guide
- OpenIntelWireless: https://openintelwireless.github.io
- AppleALC supported codecs: https://github.com/acidanthera/AppleALC/wiki/Supported-codecs
- Hackintosh.com 2026 status page: https://hackintosh.com

## Pattern Library Notes

Issues encountered and their pattern category:

| Issue | Pattern Library Category |
|-------|--------------------------|
| iGPU UHD P630 reports wrong device ID for macOS drivers | Version Mismatch |
| NVIDIA P620 has no macOS driver in current versions | Missing Dependency |
| Wi-Fi AX201 CNVi cannot be swapped to Broadcom for AirDrop | Hardware Constraint |
| CFG Lock typically not exposed in Lenovo BIOS | Config Hierarchy Override |
| Thunderbolt sleep issues across all Hackintosh laptops | State Drift |

## Status Log

| Date | Stage | Status |
|------|-------|--------|
| 2026-05-11 | Pre-build | Hardware inventory captured, decisions locked, full backup pending |
| 2026-05-11 | Stage 1 | BIOS settings checklist provided, awaiting execution |
