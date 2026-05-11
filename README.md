# ThinkPad P15v Gen 1 Hackintosh

End-of-life Intel Hackintosh build on a Lenovo ThinkPad P15v Gen 1 (20TRS00T00), targeting macOS Sonoma 14.7 as a single-boot macOS machine.

- **CPU:** Intel Xeon W-10855M (Comet Lake, 6c/12t)
- **iGPU:** Intel UHD P630 (device-id spoofed to UHD 630)
- **dGPU:** NVIDIA Quadro P620 (disabled via SSDT)
- **SMBIOS:** MacBookPro16,1
- **Bootloader:** OpenCore

## Documentation

- [WALKTHROUGH.md](WALKTHROUGH.md) - Step-by-step guide for the entire build, beginner-friendly
- [BUILD.md](BUILD.md) - Hardware inventory, decisions, kext list, and 8-stage roadmap
- [OCVALIDATE-FIXES.md](OCVALIDATE-FIXES.md) - All 23 OpenCore config validation errors and how to fix them
- [BOOT-ERRORS.md](BOOT-ERRORS.md) - Runtime boot errors encountered during install and their fixes

## Author

Thinh Le

## License

MIT License - see [LICENSE](LICENSE) for details.
