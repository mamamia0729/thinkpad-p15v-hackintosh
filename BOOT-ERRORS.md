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
