# ThinkPad P15v Gen 1 Hackintosh Build

End-of-life Intel Hackintosh project on Lenovo ThinkPad P15v Gen 1 (20TRS00T00), targeting macOS Sequoia 15.x as a macOS-only build.

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
| NVMe SK hynix PC611 | [1c5c:1639] | INCOMPATIBLE - firmware-level NVMe command timeout panics (see Build Log) |
| NVMe WD PC SN810 (replacement) | TBD | Pulled from HP ZBook - pending swap and macOS compatibility verification |
| Camera Bison UVC | USB [5986:9106] | Native UVC |
| Trackpad Synaptics I2C | I2C bus | VoodooI2C + VoodooI2CHID |
| Fingerprint reader | USB [06cb:00bd] | No driver, accept loss |
| SD Card Reader RTS525A | [10ec:525a] | No driver, accept loss |
| Thunderbolt JHL7540 (Titan Ridge) | [8086:15e7] | Disable or USB-C only |
| RAM | 32GB DDR4-3200 (single-channel, BANK 2) | Native |

## Decisions Locked In

| Decision | Choice | Rationale |
|----------|--------|-----------|
| macOS version | Sequoia 15.x | Upgraded from Sonoma 14.7.x - latest supported Intel macOS, extends security update window |
| SMBIOS | MacBookPro16,1 | 16" 2019 MBP with i7-9750H 6c/12t Coffee Lake = closest match to Xeon W-10855M |
| Wi-Fi | OpenIntelWireless, no card swap | AX201 is CNVi (integrated into PCH), AirDrop/Continuity not needed |
| Audio | AppleALC + ALC257 layout-id 17 | Matches reference build |
| dGPU | Disable NVIDIA P620 via SSDT-DDGPU.aml | Pascal architecture dead in modern macOS, iGPU drives everything |
| Disk layout | Single OS, full disk macOS, wipe Ubuntu | Cleanest path, no dual-boot EFI complexity |
| Storage target | WD PC SN810 NVMe (replacing SK hynix PC611) | Free pull from HP ZBook, replaces incompatible PC611 |

## Accepted Feature Losses

The following will NOT work in this build. Accepted as part of the design tradeoff:

- AirDrop, Handoff, Universal Clipboard, Sidecar, Apple Watch unlock (Wi-Fi card limitation)
- Fingerprint reader (no macOS driver)
- SD card reader (no macOS driver)
- Reliable Thunderbolt 3 hot-plug for displays (community-wide known issue)

What WILL work: iCloud, iMessage, FaceTime, App Store, Camera, Audio, Sleep, Ethernet, Wi-Fi (functional, just no Continuity), Bluetooth, full GPU acceleration via iGPU, Trackpad multitouch, Brightness, Battery percentage.

## The 8-Stage Build Roadmap

```
Stage 1: BIOS Settings              <- DONE
Stage 2: Download macOS Installer   <- DONE (upgraded to Sequoia 15.x)
Stage 3: Build OpenCore EFI         <- DONE
Stage 4: Write Installer to USB     <- DONE (Sequoia recovery on USB)
Stage 5: Boot Installer + Wipe NVMe + Install macOS  <- READY (pending physical NVMe swap to WD PC SN810)
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

Will use OpenCore's `macrecovery.py` to download macOS recovery installer files directly from Apple servers. No Mac required to source the installer. Originally downloaded Sonoma 14.6.1, later swapped to Sequoia 15.x.

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

## Build Log

### Session 1: 2026-05-11 (BIOS through first install attempt)

**Stage 1 (BIOS Settings): COMPLETE**

- Secure Boot: Disabled (validated via `mokutil --sb-state` on Ubuntu)
- CFG Lock: Locked at firmware level. Validated via `sudo rdmsr 0xE2` returning `0x1E008008`, bit 15 = 1. Lenovo BIOS does not expose toggle. Mitigated with `AppleXcpmCfgLock=true` in OpenCore.
- Graphics Device selector: Not exposed in BIOS. Mitigated with SSDT-DDGPU.aml hotpatch in EFI.
- Kernel DMA Protection: Disabled.
- Other Security menu items (SGX, TXT, Memory Protection, Fast Boot): Disabled per checklist.

**Stages 2 to 4 (macOS installer, OpenCore EFI, USB write): COMPLETE on Windows**

- macOS Sonoma 14.6.1 (build 23G93) installer downloaded via macrecovery.py
- BaseSystem.dmg validated at 753 MB
- OpenCore EFI built with MacBookPro16,1 SMBIOS
- USB validated structurally sound after GenSMBIOS serial generation and SSDT-XOSI.aml addition

**Stage 5 (First install attempt): BLOCKED on NVMe**

Issues hit, in order:

1. **HideAuxiliary=true hid the DMG entry from OpenCore picker.** Default config had it set TRUE. Workaround: press SPACE in OpenCore picker to reveal auxiliary entries. Permanent fix pending: set HideAuxiliary=false in Misc/Boot.

2. **First kernel panic: VoodooInput.kext duplicate UUID.** Error message: `Refusing new kext me.kishorprins.VoodooInput. v1.1.6: a prelinked copy with a different executable UUID is already present`. Followed by `vm_map_delete` panic at `vm_map.c:8235`. Root cause: VoodooInput was loaded both as standalone kext in EFI/OC/Kexts and as nested plugin inside another kext's PlugIns folder, with mismatched binary versions. Fix applied: removed duplicate Kernel/Add entry, kept standalone only. Resynced USB EFI. Result: panic resolved on retry.

3. **Second kernel panic: NVMe command timeout (CURRENT BLOCKER).** Error: `panic: nvme: ". Command timeout. Delete IO submission queue. fBuiltIn=1 MODEL=Model string not available"`. Stack trace points to `IONVMeFamily->IONVMeController18RequestAsyncEvents` with `IOTimerEventSource15timeoutSignaledEPvS0_`. macOS Sonoma userspace was already launching (launchd spawning findmymacd at PID 378, pboard at PID 377) when the kernel panicked on NVMe controller timeout. Boot args attempted: default set, then with `-wegnoegpu` added. Not yet tried: `nvme_force_uefi=1`. Root cause: SK hynix PC611 NVMe controller firmware has known incompatibilities with macOS IONVMeFamily driver. Initial hardware analysis rated PC611 as "native, no NVMeFix needed" based on PCI device ID family match. That assessment missed the firmware-level behavior issue.

Stage 5 status: BLOCKED. Decision pending:
- Option A: Try `nvme_force_uefi=1` boot arg, accept slower UEFI NVMe protocol, accept possible runtime panics under heavy I/O
- Option B: Replace NVMe with Samsung 970 EVO Plus, WD SN770, or Crucial P5 Plus 1TB. Clone Ubuntu off PC611 first, swap drive, clean macOS install. Estimated cost $50 to $80, one-day delay.

### Session 2: 2026-05-11 (NVMe solution found, installer upgraded to Sequoia)

**Hardware discovery: Free WD PC SN810 NVMe from HP ZBook**

Found a WD PC SN810 NVMe drive pulled from an old HP ZBook - free replacement for the incompatible SK hynix PC611. This resolves the Stage 5 NVMe blocker at zero cost (Option B fulfilled without purchase). Drive swap pending - physical NVMe replacement is next step before reattempting Stage 5.

**Installer upgraded: Sonoma 14.6.1 -> Sequoia 15.x**

Replaced the macOS recovery installer on the USB from Sonoma 14.6.1 to Sequoia 15.x:
- Downloaded via `macrecovery.py -b Mac-937A206F2EE63C01 -m 00000000000000000 download` (product 696-28424, catalog 082-33203)
- New BaseSystem.dmg: 884 MB (Sequoia) vs 753 MB (Sonoma)
- Sonoma files backed up as BaseSystem_Sonoma_14.6.1.dmg/chunklist in staging directory
- OpenCore EFI on USB left unchanged - same config works for both Sonoma and Sequoia
- Rationale: Sequoia extends the security update window beyond Sonoma's EOL, and Comet Lake is fully supported

**Boot error: HfsPlus.efi "cannot be found" after Sequoia copy**

After swapping the NVMe and attempting Stage 5, OpenCore halted with `OC: Driver HfsPlus.efi at 0 cannot be found!`. The file was physically present and SHA1-matched the official binary - the 884 MB Sequoia copy likely corrupted FAT32 directory entries. Fixed by deleting and re-copying all three drivers from the build directory to USB. Also populated the previously-empty build directory `EFI/OC/Drivers/` as canonical source. See [BOOT-ERRORS.md](BOOT-ERRORS.md) Error 5 for full details.

Stage 5 status: READY for boot retry (NVMe swapped, installer upgraded, HfsPlus.efi fixed).

## Lessons Learned (Session 1)

1. PASS at file-presence level in pre-Stage-5 validation does not prove specific config values match the target hardware exactly. Static validation catches structural issues but not behavioral mismatches.

2. SPACE in OpenCore picker is a critical debugging keystroke. It reveals auxiliary entries (DMG mounts, Recovery volumes) hidden by HideAuxiliary=true defaults.

3. Kernel panics that occur deep in userspace boot (after launchd starts spawning services) indicate the build configuration is structurally sound and remaining issues are hardware-specific or driver-specific, not config errors.

4. Hardware compatibility analysis for Hackintosh must include firmware-level community reports, not just PCI device ID family matching. The SK hynix PC611 case is a clear example: same Navi-class PCI family as supported drives, but firmware quirks break macOS's NVMe driver.

5. The reference build approach worked. The community EFI for the same ThinkPad model was a reliable starting point, and the divergences (different Wi-Fi card, Xeon vs i7) were manageable. The hardware-specific failure (NVMe) was not in the reference build because that author had a different NVMe model.

## Pattern Library Notes

Issues encountered and their pattern category:

| Issue | Pattern Library Category |
|-------|--------------------------|
| iGPU UHD P630 reports wrong device ID for macOS drivers | Version Mismatch |
| NVIDIA P620 has no macOS driver in current versions | Missing Dependency |
| Wi-Fi AX201 CNVi cannot be swapped to Broadcom for AirDrop | Hardware Constraint |
| CFG Lock typically not exposed in Lenovo BIOS | Config Hierarchy Override |
| Thunderbolt sleep issues across all Hackintosh laptops | State Drift |
| HideAuxiliary=true hides macOS installer entries from OpenCore picker | Config Hierarchy Override |
| VoodooInput.kext loaded from standalone and nested plugin paths with mismatched UUIDs | Version Mismatch |
| SK hynix PC611 NVMe firmware incompatible with macOS IONVMeFamily despite matching PCI device ID family | Hardware Constraint |
| Hardware compatibility rated from PCI device ID alone misses firmware-level behavior issues | Missing Dependency |

## Status Log

| Date | Stage | Status |
|------|-------|--------|
| 2026-05-11 | Pre-build | Hardware inventory captured, decisions locked, full backup pending |
| 2026-05-11 | Stage 1 | BIOS settings checklist provided, awaiting execution |
| 2026-05-11 | Stage 2 | DONE: macOS Sonoma recovery downloaded (BaseSystem.dmg 753MB) |
| 2026-05-11 | Stage 3 | DONE: OpenCore EFI built - 18 kexts, 5 SSDTs, 3 drivers, config.plist complete |
| 2026-05-11 | Stage 4 | DONE: USB formatted (FAT32 GPT), EFI + recovery copied to E: (OCUSB) |
| 2026-05-11 | Stage 4 | BLOCKER: config.plist PlatformInfo needs GenSMBIOS serials before first boot |
| 2026-05-11 | Stage 4 | RESOLVED: GenSMBIOS serials generated, SSDT-XOSI added, ocvalidate clean |
| 2026-05-11 | Stage 5 attempt 1 | VoodooInput duplicate UUID panic resolved on retry. Blocked on SK hynix PC611 NVMe command timeout. Decision pending: try nvme_force_uefi=1 boot arg, or swap NVMe to Samsung 970 EVO Plus class drive. |
| 2026-05-11 | Pre-Stage 5 prep | NVMe blocker resolved: free WD PC SN810 from HP ZBook replaces incompatible PC611. Installer swapped from Sonoma 14.6.1 to Sequoia 15.x (884 MB). Physical NVMe swap pending. |
| 2026-05-11 | Stage 5 attempt 2 | HfsPlus.efi "cannot be found" - FAT32 corruption from large file copy. Fixed by re-syncing drivers. Ready for boot retry. |
