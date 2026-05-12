# Boot Errors and Fixes

Runtime boot errors encountered during the ThinkPad P15v Gen 1 Hackintosh build. These are different from config.plist schema errors (see [OCVALIDATE-FIXES.md](OCVALIDATE-FIXES.md)).

---

## Error 1: Stuck at `EXITBS:START` with `Err(0xE)` on root hash

**Date:** 2026-05-11
**Stage:** 5 (first boot attempt from USB installer)

### Symptoms

Verbose boot output froze at:

```
EB|#LOG:EXITBS:START
```

Lines above it showed:

```
EB.LD.OFS|OPEN!  Err(0xE)  <usr\standalone\OS.dmg.root_hash>
EB.RHL.LRI!!     Err(0xE)  <- EB.LD.LF
EB.BST.FBS!!     Err(0xE)  <- EB.RHL.LRI
EB|#LOG:EXITBS:START
```

The system hung indefinitely after `EXITBS:START`. No reboot, no progress.

### Diagnosis

Two separate issues compounding:

1. **`Err(0xE)` = EFI_NOT_FOUND on `OS.dmg.root_hash`**
   - `SecureBootModel` was set to `Default`, which enforces Apple Secure Boot validation on the recovery DMG
   - The recovery image downloaded via `macrecovery.py` is valid but `Default` mode was rejecting it
   - Related setting `DmgLoading` was set to `Signed`, adding a second validation gate

2. **`EXITBS:START` hang**
   - `SetupVirtualMap` was set to `false` (Dortania's general Comet Lake recommendation)
   - This ThinkPad's BIOS firmware requires `SetupVirtualMap = true` to properly hand off memory mapping from UEFI to the macOS kernel
   - Without it, the ExitBootServices call never completes

### Root Cause

The combination of Secure Boot validation failing (preventing the kernel from loading) AND incorrect virtual memory mapping (preventing the boot services handoff) caused a hard freeze.

### Fix

Three values changed in `config.plist`:

| Key | Path in config.plist | Before | After | Why |
|-----|---------------------|--------|-------|-----|
| SecureBootModel | Misc/Security/SecureBootModel | `Default` | `Disabled` | Stop rejecting the recovery DMG's root hash |
| DmgLoading | Misc/Security/DmgLoading | `Signed` | `Any` | Allow loading of recovery DMG without signature verification |
| SetupVirtualMap | Booter/Quirks/SetupVirtualMap | `false` | `true` | ThinkPad P15v BIOS needs virtual memory map setup for ExitBootServices to complete |

### How to Apply

Using Python:

```python
import plistlib

with open('E:/EFI/OC/config.plist', 'rb') as f:
    p = plistlib.load(f)

p['Misc']['Security']['SecureBootModel'] = 'Disabled'
p['Misc']['Security']['DmgLoading'] = 'Any'
p['Booter']['Quirks']['SetupVirtualMap'] = True

with open('E:/EFI/OC/config.plist', 'wb') as f:
    plistlib.dump(p, f, fmt=plistlib.FMT_XML, sort_keys=False)
```

Or manually in a text editor:
- Search for `SecureBootModel`, change `Default` to `Disabled`
- Search for `DmgLoading`, change `Signed` to `Any`
- Search for `SetupVirtualMap`, change `false` to `true`

### Notes

- `SetupVirtualMap` behavior is firmware-specific. Dortania recommends `false` for Comet Lake, but ThinkPad P15v Gen 1 (BIOS N30ET61W 1.97) requires `true`. Always check your specific BIOS version.
- Disabling `SecureBootModel` is safe for installation. You can re-enable it later with `SecureBootModel = j137` (MacBookPro16,1's board identifier) once macOS is fully installed and working, but it's not required.
- After applying these fixes, `ocvalidate.exe` still reports 0 errors.

### Pattern

| Issue | Pattern Category |
|-------|-----------------|
| SecureBootModel rejecting valid recovery DMG | Config Value Mismatch (default too restrictive) |
| SetupVirtualMap wrong for specific firmware | Hardware Constraint (firmware-specific behavior) |
| Two errors masking each other | Compound Failure (fix both to see progress) |

---

## Error 2: Kernel Panic - VoodooInput Duplicate UUID

**Date:** 2026-05-11
**Stage:** 5 (second boot attempt from USB installer)

### Symptoms

Verbose boot progressed past `EXITBS:START` (Error 1 fix worked) but hit a kernel panic:

```
Refusing new kext io.VoodooInput - v1.1.6: a prelinked copy with a different executable UUID is already present.
```

Followed by a full panic backtrace and halt.

### Diagnosis

Two copies of VoodooInput.kext existed on the USB, both registered in config.plist:

| Location | Version | SHA1 |
|----------|---------|------|
| VoodooI2C.kext/Contents/PlugIns/VoodooInput.kext | 1.1.6 | e37c0005... |
| VoodooPS2Controller.kext/Contents/PlugIns/VoodooInput.kext | 1.1.6 | 7d40d66d... |

Same version, same bundle identifier (`me.kishorprins.VoodooInput`), but **different compiled binaries** (different SHA1 hashes). When both load, the kernel sees two kexts claiming the same identifier with different UUIDs and panics.

### Root Cause

Both VoodooI2C and VoodooPS2Controller ship their own copy of VoodooInput as a plugin. Our config.plist had explicit `Kernel/Add` entries for both:

- Entry [18]: `VoodooI2C.kext/Contents/PlugIns/VoodooInput.kext` (Enabled)
- Entry [24]: `VoodooPS2Controller.kext/Contents/PlugIns/VoodooInput.kext` (Enabled)

Only one can load. The physical files inside the parent kexts don't need to be deleted - just don't tell OpenCore to load both.

### Fix

Removed the VoodooI2C nested VoodooInput entry from `Kernel/Add`. Kept the VoodooPS2Controller copy (VoodooPS2 is the canonical upstream source for VoodooInput).

Using Python:

```python
import plistlib

with open('E:/EFI/OC/config.plist', 'rb') as f:
    p = plistlib.load(f)

p['Kernel']['Add'] = [
    k for k in p['Kernel']['Add']
    if k.get('BundlePath','') != 'VoodooI2C.kext/Contents/PlugIns/VoodooInput.kext'
]

with open('E:/EFI/OC/config.plist', 'wb') as f:
    plistlib.dump(p, f, fmt=plistlib.FMT_XML, sort_keys=False)
```

### After Fix

- VoodooInput entries in config.plist: **1** (VoodooPS2Controller copy only)
- Total kext entries: 24 (was 25)
- ocvalidate: 0 errors

### Pattern

| Issue | Pattern Category |
|-------|-----------------|
| Two kext bundles shipping the same plugin | Dependency Conflict (diamond dependency) |
| Same identifier, different binary hashes | UUID Collision |
| Config listing both copies explicitly | Config Duplication |

### Prevention

When multiple kexts bundle the same plugin (VoodooInput, VoodooGPIO, etc.), only register ONE in config.plist. Check for duplicates with:

```python
import plistlib
with open('config.plist', 'rb') as f:
    p = plistlib.load(f)
seen = {}
for k in p['Kernel']['Add']:
    name = k['BundlePath'].split('/')[-1]
    if name in seen:
        print(f'DUPLICATE: {name}')
        print(f'  1: {seen[name]}')
        print(f'  2: {k["BundlePath"]}')
    seen[name] = k['BundlePath']
```

---

## Error 3: Kernel Panic - IOGraphics / dGPU not fully disabled

**Date:** 2026-05-11
**Stage:** 5 (third boot attempt from USB installer)

### Symptoms

Verbose boot got past `EXITBS:START` and into IOKit service initialization. Services like `com.apple.logd` and `FinderKit` started loading, then panic:

```
vm_shared_region_start_address() failed
```

Panic backtrace included:
- `com.apple.iokit.IOGraphicsFamily`
- `com.apple.iokit.IONDRVSupport`
- `com.apple.iokit.IOPCIFamily`

### Diagnosis

The presence of `IONDRVSupport` in the backtrace indicates the NVIDIA Quadro P620 dGPU was still being probed during graphics initialization, despite `SSDT-DDGPU.aml` being present.

The prebuilt `SSDT-dGPU-Off.aml` from Dortania uses generic ACPI paths (`_SB.PCI0.PEG0.PEGP`) that may not match the ThinkPad P15v's specific ACPI path for the NVIDIA GPU. If the path doesn't match, the SSDT has no effect and the dGPU remains active. macOS has no driver for NVIDIA Pascal GPUs, causing the graphics subsystem to panic.

### Fix

Added `-wegnoegpu` to boot-args. This is a WhateverGreen flag that disables all discrete/external GPUs at the driver level, regardless of ACPI path.

```
boot-args: -v keepsyms=1 debug=0x100 alcid=17 -igfxblr -wegnoegpu
```

This is a belt-and-suspenders approach: SSDT-DDGPU handles it at the ACPI level, `-wegnoegpu` handles it at the WhateverGreen/driver level. Even if one fails, the other catches it.

### How to Apply

Using Python:

```python
import plistlib

with open('E:/EFI/OC/config.plist', 'rb') as f:
    p = plistlib.load(f)

nvram = p['NVRAM']['Add']['7C436110-AB2A-4BBB-A880-FE41995C9F82']
if '-wegnoegpu' not in nvram['boot-args']:
    nvram['boot-args'] += ' -wegnoegpu'

with open('E:/EFI/OC/config.plist', 'wb') as f:
    plistlib.dump(p, f, fmt=plistlib.FMT_XML, sort_keys=False)
```

Or manually: find `boot-args` in config.plist, append ` -wegnoegpu` to the string.

### Notes

- If macOS installs successfully with `-wegnoegpu`, the SSDT-DDGPU can be investigated post-install by dumping the real ACPI tables with `SysReport` and finding the correct ACPI path for the NVIDIA GPU
- `-wegnoegpu` has zero performance cost since we're using iGPU only anyway
- This flag is permanent-safe - no reason to remove it on a laptop where the dGPU will never be used in macOS

### Pattern

| Issue | Pattern Category |
|-------|-----------------|
| Prebuilt SSDT using generic ACPI path | Hardware Constraint (device-specific ACPI paths) |
| dGPU probe causing graphics panic | Missing Dependency (no NVIDIA driver in macOS) |
| WhateverGreen flag as software fallback | Defense in Depth (two mechanisms for same goal) |

---

## Error 4: Kernel Panic - NVMe Command Timeout (SK hynix PC611)

**Date:** 2026-05-11
**Stage:** 5 (third boot attempt - after VoodooInput and dGPU fixes)
**Status:** CURRENT BLOCKER

### Symptoms

Boot progressed significantly - macOS userspace was already running (launchd spawning `findmymacd` at PID 378, `pboard` at PID 377). Then kernel panic:

```
panic: nvme: "". Command timeout. Delete IO submission queue.
fBuiltIn=1 MODEL=Model string not available
```

Stack trace:
```
IONVMeFamily -> IONVMeController::RequestAsyncEvents
IOTimerEventSource::timeoutSignaled
```

### Diagnosis

The SK hynix PC611 NVMe controller (PCI [1c5c:1639]) has firmware-level incompatibilities with macOS's `IONVMeFamily` driver. The drive works fine in Linux and Windows, but macOS's NVMe driver sends async event requests that the PC611 firmware fails to respond to within the timeout window.

Key indicators:
- Panic happens AFTER successful boot into userspace (not during early boot)
- `MODEL=Model string not available` confirms macOS can't properly identify the drive
- `fBuiltIn=1` means macOS detected it as an internal drive
- The panic is in the NVMe async event handler, not in read/write I/O

This was missed in the pre-build hardware analysis. The PC611 was rated "Native, no NVMeFix needed" based on PCI device ID family matching. That assessment was incorrect - firmware behavior matters more than device ID for NVMe compatibility.

### Options

| Option | Approach | Pros | Cons |
|--------|----------|------|------|
| A | Add `nvme_force_uefi=1` boot arg | No cost, immediate test | Slower UEFI NVMe protocol, possible runtime panics under heavy I/O |
| B | Replace NVMe drive | Guaranteed fix with known-good hardware | $50-80 cost, one-day delay, need to clone Ubuntu first |

Recommended replacement drives (confirmed macOS compatible):
- Samsung 970 EVO Plus 1TB
- WD Black SN770 1TB
- Crucial P5 Plus 1TB

### Pattern

| Issue | Pattern Category |
|-------|-----------------|
| NVMe firmware incompatible despite matching PCI device ID family | Hardware Constraint |
| Pre-build analysis missed firmware-level behavior | Missing Dependency (community reports needed, not just specs) |
| Panic deep in userspace proves config is sound | Defense in Depth (isolates problem to hardware) |

---

## Error 5: OC: Driver HfsPlus.efi at 0 cannot be found!

**Date:** 2026-05-11
**Stage:** 5 (boot attempt after NVMe swap to WD PC SN810 and Sequoia installer upgrade)

### Symptoms

OpenCore picker loaded but immediately halted with:

```
OC: Driver HfsPlus.efi at 0 cannot be found!
Halting on critical error
```

No boot picker displayed. Hard stop.

### Diagnosis

HfsPlus.efi was physically present on the USB at `E:\EFI\OC\Drivers\HfsPlus.efi` (37,892 bytes) and SHA1-matched the official Acidanthera OcBinaryData release (`7356a825b619cd954a4d83599d6032c38ab009d5`). config.plist `UEFI/Drivers/Add[0]` correctly referenced `HfsPlus.efi`.

The file was NOT missing or corrupted at the binary level. The likely cause was FAT32 filesystem directory/allocation table corruption from the earlier 884 MB Sequoia BaseSystem.dmg copy operation to the same USB partition. The large file write may have corrupted neighboring FAT32 directory entries, making the file invisible to OpenCore's UEFI filesystem driver despite being readable from Windows/Linux.

Also discovered: the build directory's `EFI/OC/Drivers/` folder was empty - drivers only existed on the USB, not in the repo's build directory.

### Fix

1. Downloaded fresh HfsPlus.efi from Acidanthera OcBinaryData repo as reference
2. Populated the build directory's `EFI/OC/Drivers/` with all three drivers (HfsPlus.efi, OpenRuntime.efi, OpenCanopy.efi)
3. Deleted all three drivers from USB and re-copied from build directory to force fresh FAT32 directory entries
4. Verified SHA1 match between USB and build directory copies
5. Cross-checked all config.plist driver references against folder contents (3/3 match)

### Verification

| Check | Result |
|-------|--------|
| HfsPlus.efi on USB | 37,892 bytes, SHA1 7356a825b619cd954a4d83599d6032c38ab009d5 |
| OpenRuntime.efi on USB | 24,576 bytes, SHA1 c588ebc31358d3132673a424315d58c075efc134 |
| OpenCanopy.efi on USB | 114,688 bytes, SHA1 b92d8cea37cbd7a6c495073eee9e14df73d88522 |
| All config.plist drivers exist in folder | Yes (3/3) |
| All folder drivers referenced in config.plist | Yes (3/3) |

### Pattern

| Issue | Pattern Category |
|-------|-----------------|
| Large file copy corrupting FAT32 directory entries | Filesystem Corruption (write side-effect) |
| File present on disk but invisible to UEFI driver | Environmental Mismatch (OS vs firmware filesystem view) |
| Build directory missing drivers (only on USB) | Sync Gap (source of truth incomplete) |

### Prevention

- After any large file write to a FAT32 USB, re-verify all existing files by deleting and re-copying them to force fresh directory entries
- Keep the build directory's `EFI/OC/Drivers/` populated as the canonical source - never let the USB be the only copy
- Run a driver cross-check (config.plist vs folder contents) before every boot attempt
