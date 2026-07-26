# KSU_Builder

A GitHub Actions-based kernel building automation framework for compiling custom Android kernels with KernelSU and optional SUSFS support across multiple device targets.

## Overview

KSU_Builder is a comprehensive CI/CD solution that streamlines the process of building custom Linux kernels with KernelSU root management for Android devices. Using GitHub Actions workflows, it automates kernel compilation, patching, and packaging into flashable AnyKernel3 modules.

## Features

- 🔄 **Automated Kernel Compilation** - Build kernels directly from GitHub Actions with minimal configuration
- 🔌 **KernelSU Integration** - Multiple KernelSU variants supported:
  - KernelSU-by-xx (Official fork with tamper syscall table support)
  - KernelSU-Next (Advanced experimental version)
  - ReSukiSU (Alternative implementation)
- 🛡️ **SUSFS Support** - Optional SU filesystem hooks for enhanced security and detection evasion
- 📱 **Multi-Device Support** - Pre-configured workflows for various device models
- 📦 **AnyKernel3 Packaging** - Automatic flashable ZIP generation with device-specific configurations
- 🔧 **Flexible Clang Toolchains** - Support for multiple LLVM/Clang versions (r547379, r563880, r563880c, etc.)
- 📡 **Telegram Integration** - Optional build status notifications via Telegram API

## Quick Start

### Prerequisites

Before using KSU_Builder, ensure you have:
- A GitHub account with repository access
- Familiarity with kernel building concepts
- Knowledge of your device's kernel branch and defconfig name

### Setup Instructions

1. **Fork the Repository**
   - Click the Fork button to create your own copy
   - Ensure you sync regularly before building to get the latest updates

2. **Navigate to Actions**
   - Go to your forked repository
   - Click on the "Actions" tab
   - Select a workflow matching your device type

3. **Configure Build Parameters**
   - **Clang Version**: Choose appropriate toolchain version for your Android version
     - `clang-r547379` for Android 16 (A16QP0)
     - `r563880` / `r563880c` for Android 16 (A16QP2)
   - **Kernel Source**: Select your kernel source repository
   - **Kernel Branch**: Specify the branch (e.g., `lineage-7.1` for LineageOS 14.1, `lineage-16.0` for LineageOS 16.0)
   - **KernelSU Type**: Choose from available KernelSU/SUSFS combinations
   - **Device Codename**: Enter your device's codename

4. **Run Workflow**
   - Click "Run workflow" and confirm
   - Monitor the build progress in real-time
   - Upon completion, download the kernel from releases or artifacts

## Available Workflows

| Workflow | Device | Purpose |
|----------|--------|---------|
| `KSU.yml` | Generic ARM64 | Main GKI/Non-GKI kernel builder |
| `Non-Gki.yml` | Non-GKI devices | Non-GKI specific compilation |
| `Personal.yml` | OnePlus/Pixel (ARM64) | Custom personal kernel builds |
| `KSU-NEXT.yml` | ARM64 devices | KernelSU-Next + SUSFS integration |
| `KSU-SUSFS.yml` | ARM64 devices | SUSFS-focused builds |
| `violet.yml` | Redmi Note 7 Pro | Optimized build for Redmi Note 7 Pro |
| `rmx2020.yml` | Realme RMX2020 series | Realme devices support |
| `build.yml` | Flagship devices | Kalama SOC (Pixel/Sony/OnePlus flagship) |

## Kernel Build Configuration

### Defconfig Selection

The defconfig file determines kernel features and device-specific settings. Common examples:
- Non-GKI: Device-specific defconfig in `arch/arm64/configs/`
- GKI: Universal `gki_defconfig` with vendor overlays

### KernelSU Configuration

When KernelSU is enabled, the following configurations are automatically applied:
```bash
CONFIG_KSU=y                        # Enable KernelSU
CONFIG_KPROBES=y                    # KProbe support
CONFIG_KPROBE_EVENTS=y              # KProbe events
CONFIG_KSU_KPROBE_HOOKS=y           # KernelSU KProbe hooks
CONFIG_OVERLAY_FS=y                 # Overlay filesystem support
```

### SUSFS Configuration (Optional)

For SUSFS builds, additional configs are applied:
```bash
CONFIG_KSU_SUSFS=y                  # Enable SUSFS
CONFIG_KSU_SUSFS_SUS_PATH=y         # Path hiding
CONFIG_KSU_SUSFS_SUS_MOUNT=y        # Mount hiding
CONFIG_KSU_SUSFS_SUS_KSTAT=y        # Kstat hiding
CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y
```

## Output Artifacts

After successful compilation, the following files are generated:

- **Flashable ZIP**: `{device}_{ksu_type}_{timestamp}.zip` - Ready to flash via recovery
- **Kernel Image**: `Image` or `Image.gz` - Raw kernel binary
- **DTB/DTBO**: Device tree binaries for device-specific configurations
- **Build Log**: `build.log` - Full compilation output for debugging

## Supported KernelSU Variants

### KernelSU-by-xx
- **Source**: https://github.com/backslashxx/KernelSU
- **Features**: Tamper syscall table configuration support
- **Best For**: Maximum compatibility and performance tuning

### KernelSU-Next
- **Source**: https://github.com/KernelSU-Next/KernelSU-Next
- **Features**: Experimental features, latest improvements
- **Best For**: Early adopters, testing cutting-edge features

### ReSukiSU
- **Source**: https://github.com/ReSukiSU/ReSukiSU
- **Features**: Alternative implementation, SUSFS integration
- **Best For**: SUSFS support and alternative implementations

## Device-Specific Notes

### Redmi Note 7 Pro (violet)
- **Kernel Branch**: Check your specific ROM's kernel repository
- **Supported KernelSU**: KernelSU-by-xx, ReSukiSU-with-susfs
- **Build Profile**: Optimized in `violet.yml` workflow
- **Defconfig**: Device-specific configuration in kernel source

## Troubleshooting

### Build Failures

1. **Configuration Errors**
   - Verify the correct `defconfig_name` for your device
   - Ensure kernel branch exists in the source repository
   - Check Clang version compatibility with kernel version

2. **Compilation Errors**
   - Review `build.log` in artifacts for detailed error messages
   - Common issues: Missing dependencies, incompatible patches
   - Try adjusting Clang version or kernel source

3. **Flashing Issues**
   - Verify device codename matches your device
   - Ensure AnyKernel3 device name is correct
   - Check DTB/DTBO compatibility

## Related Resources

- **KSU Toolkit**: https://github.com/backslashxx/ksu_toolkit - Utilities for KernelSU management
- **Inferno's Build**: https://github.com/inferno0230/kernel_oneplus_sm8550-CI - Alternative build reference
- **AnyKernel3**: https://github.com/Kernel-SU/AnyKernel3 - Flashable kernel packaging framework

## Requirements & Support

- **Minimum Android Version**: Android 13 (API 33)
- **Supported Architecture**: ARM64 (aarch64)
- **Build Time**: 20-45 minutes depending on kernel size and GitHub Actions concurrency
- **Storage**: 50+ GB free space recommended on build machine

## Important Notes

⚠️ **Read the README First** - This project requires understanding of kernel compilation and your device's specifications

⚠️ **Kernel Branch Knowledge** - You must know your device's specific kernel branch before building

⚠️ **SUSFS Caveat** - Some SUSFS implementations may have compatibility issues; refer to SUSFS maintainer (simonpunk) for updates

⚠️ **Testing Recommended** - Always test builds on a non-critical device before wider deployment

## License

This project builds upon public kernel sources and open-source tools. Refer to individual component licenses:
- Linux Kernel: GPL v2
- KernelSU: GPL v2
- AnyKernel3: Various (per original maintainer)

## Contributing

Contributions are welcome! Areas for improvement:
- Additional device support configurations
- Enhanced error handling and logging
- Documentation improvements
- Workflow optimizations

## Disclaimer

This project is provided as-is for educational and personal use. Users are responsible for:
- Ensuring device compatibility
- Understanding kernel modification risks
- Complying with applicable licenses
- Testing before production deployment

**Flashing custom kernels may void warranty and brick devices if done incorrectly.**

---

**Last Updated**: July 2026
**Main Branch Support**: Android 16 (A16) and later
