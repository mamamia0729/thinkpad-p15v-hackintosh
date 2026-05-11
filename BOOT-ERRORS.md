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
