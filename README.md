# Raspberry Pi 5 Custom Firmware Project

This project aims to build a custom Linux firmware image for the Raspberry Pi 5, starting with the kernel.

## Prerequisites

*   macOS (Tested on Apple Silicon)
*   Homebrew
*   AArch64 Cross-Compiler Toolchain (e.g., `aarch64-unknown-linux-gnu`)
*   QEMU (System AArch64)

Install prerequisites using Homebrew:

```bash
brew tap messense/macos-cross-toolchains
brew install aarch64-unknown-linux-gnu
brew install qemu
```

## Building

Use the provided `Makefile`. You **must** specify the `CROSS_COMPILE` variable pointing to your installed AArch64 toolchain prefix.

1.  **Build the kernel:**
    ```bash
    make CROSS_COMPILE=aarch64-unknown-linux-gnu- all
    ```

2.  **Clean build artifacts:**
    ```bash
    make clean
    ```

## Running (QEMU - Kernel Only)

To test boot the kernel (without a root filesystem, expect a panic):

```bash
make CROSS_COMPILE=aarch64-unknown-linux-gnu- run-qemu
```

## Next Steps

- Create a root filesystem (e.g., using BusyBox).
- Integrate Slint UI C++ application.
- Create a bootable SD card image. 