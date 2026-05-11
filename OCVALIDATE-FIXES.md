# ocvalidate Errors and Fixes

OpenCore 1.0.7 `ocvalidate.exe` against `config.plist` built from scratch for ThinkPad P15v Gen 1 (Comet Lake).

Initial run returned **23 errors**. All resolved in 4 iterations.

## Round 1: 20 Serialisation + 1 CheckMisc + 2 CheckUefi = 23 errors

### Missing Keys (Serialisation)

These keys are required by OpenCore 1.0.7's schema but were absent from the hand-built config.plist. Most are `false`/empty defaults.

| # | Error | Section | Fix | Value |
|---|-------|---------|-----|-------|
| 1 | `Missing key SyncTableIds` | ACPI/Quirks | Added key | `false` |
| 2 | `Missing key ClearTaskSwitchBit` | Booter/Quirks | Added key (initially placed in Kernel/Quirks by mistake — moved in Round 2) | `false` |
| 3 | `Missing key FixupAppleEfiImages` | Booter/Quirks | Added key | `false` |
| 4 | `Missing key CustomPciSerialDevice` | Kernel/Quirks | Added key (took 3 rounds to find correct location — see Round 3-4 notes below) | `false` |
| 5 | `Missing key DisableIoMapperMapping` | Kernel/Quirks | Added key | `false` |
| 6 | `Missing key ExternalDiskIcons` | Kernel/Quirks | Added key | `false` |
| 7 | `Missing key ForceAquantiaEthernet` | Kernel/Quirks | Added key | `false` |
| 8 | `Missing key ForceSecureBootScheme` | Kernel/Quirks | Added key | `false` |
| 9 | `Missing key IncreasePciBarSize` | Kernel/Quirks | Added key | `false` |
| 10 | `Missing key InstanceIdentifier` | Misc/Boot | Added key | `""` (empty string) |
| 11 | `No schema for UseForDebugLog at 9 index, context <Custom>` | Misc/Serial/Custom | Removed key (not valid in OC 1.0.7 Custom schema) | N/A |
| 12 | `Missing key ExtendedTxFifoSize` | Misc/Serial/Custom | Added key | `64` |
| 13 | `Missing key UseHardwareFlowControl` | Misc/Serial/Custom | Added key | `false` |
| 14 | `Missing key FullNvramAccess` | Misc/Tools[*] | Added key to each tool entry | `false` |
| 15 | `Missing key ConsoleFont` | UEFI/Output | Added key | `""` (empty string) |
| 16 | `Missing key InitialMode` | UEFI/Output | Added key | `"Auto"` |
| 17 | `No schema for Unicode at 18 index, context <ProtocolOverrides>` | UEFI/ProtocolOverrides | Removed `Unicode` key (renamed to `UnicodeCollation` in OC 1.0.7) | N/A |
| 18 | `Missing key UnicodeCollation` | UEFI/ProtocolOverrides | Added key (replaces old `Unicode`) | `false` |
| 19 | `Missing key AppleInput` | UEFI | Added entire section with defaults | See below |
| 20 | `Missing key Unload` | UEFI | Added empty array | `[]` |

### CheckMisc Error

| # | Error | Fix |
|---|-------|-----|
| 21 | `Last byte of Misc->Serial->PciDeviceInfo must be 0xFF!` | Changed PciDeviceInfo from `00 00 00 00 00` to `00 00 00 00 FF` |

### CheckUefi Errors

| # | Error | Fix |
|---|-------|-----|
| 22 | `OpenRuntime.efi at UEFI->Drivers[1] should have its LoadEarly set to FALSE unless OpenVariableRuntimeDxe.efi is in use!` | Set `LoadEarly` to `false` for OpenRuntime.efi driver entry |
| 23 | `UEFI->Output->InitialMode is illegal` | Set `InitialMode` to `"Auto"` (valid values: Auto, Text, Graphics) |

## Round 2: 6 errors

After first fix pass, 6 remained:

| # | Error | Root Cause | Fix |
|---|-------|-----------|-----|
| 1 | `Missing key ClearTaskSwitchBit, context <Quirks>` | Was added to Kernel/Quirks instead of Booter/Quirks | Moved to Booter/Quirks |
| 2 | `No schema for ClearTaskSwitchBit at 22 index, context <Quirks>` | Same — wrong section | Removed from Kernel/Quirks |
| 3 | `Missing key CustomPciSerialDevice, context <Quirks>` | Not yet placed correctly | Tried Misc/Serial — wrong |
| 4-6 | `Missing key PointerPollMask/Max/Min, context <AppleInput>` | AppleInput section was incomplete | Added `PointerPollMask: -1`, `PointerPollMax: 80`, `PointerPollMin: 10` |

## Round 3: 2 errors

| # | Error | Root Cause | Fix |
|---|-------|-----------|-----|
| 1 | `Missing key CustomPciSerialDevice, context <Quirks>` | Placed in Misc/Serial — wrong section | Searched official Sample.plist |
| 2 | `No schema for CustomPciSerialDevice at 3 index, context <Serial>` | Same | Found correct location: Kernel/Quirks |

### How we found the correct location

Extracted `Docs/Sample.plist` from `OpenCore-1.0.7-RELEASE.zip` and ran a recursive search:

```python
import plistlib
with open('Sample.plist', 'rb') as fh:
    p = plistlib.load(fh)
def search(d, prefix=''):
    if isinstance(d, dict):
        for k,v in d.items():
            if k == 'CustomPciSerialDevice':
                print(f'Location: {prefix}/{k} = {v}')
            search(v, f'{prefix}/{k}')
search(p)
```

Result: `Location: /Kernel/Quirks/CustomPciSerialDevice = False`

## Round 4: 0 errors

```
Completed validating E:/EFI/OC/config.plist in 1 ms. No issues found.
```

## UEFI/AppleInput — Full Default Section

This entire section was missing and had to be created:

```xml
<key>AppleInput</key>
<dict>
    <key>AppleEvent</key>
    <string>Builtin</string>
    <key>CustomDelays</key>
    <false/>
    <key>GraphicsInputMirroring</key>
    <true/>
    <key>KeyInitialDelay</key>
    <integer>50</integer>
    <key>KeySubsequentDelay</key>
    <integer>5</integer>
    <key>PointerDwellClickTimeout</key>
    <integer>0</integer>
    <key>PointerDwellDoubleClickTimeout</key>
    <integer>0</integer>
    <key>PointerDwellRadius</key>
    <integer>0</integer>
    <key>PointerPollMask</key>
    <integer>-1</integer>
    <key>PointerPollMax</key>
    <integer>80</integer>
    <key>PointerPollMin</key>
    <integer>10</integer>
    <key>PointerSpeedDiv</key>
    <integer>1</integer>
    <key>PointerSpeedMul</key>
    <integer>1</integer>
</dict>
```

## Lessons Learned

1. **Don't hand-build config.plist from memory.** Always start from the official `Docs/Sample.plist` in the OpenCorePkg release and strip down, rather than building up from scratch. The schema changes between OC versions and missing keys cause validation failures.

2. **Key placement matters.** OpenCore has identically-named `Quirks` dicts under ACPI, Booter, Kernel, and UEFI. `ocvalidate` error messages say `context <Quirks>` without specifying *which* Quirks section. When in doubt, search `Sample.plist`.

3. **Schema renames between versions.** `Unicode` was renamed to `UnicodeCollation` in a recent OC version. `UseForDebugLog` was removed from `Misc/Serial/Custom`. Always validate against the matching OC version.

4. **Run `ocvalidate` early and often.** It catches structural issues that would cause silent boot failures.
