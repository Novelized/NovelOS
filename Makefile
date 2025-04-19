# Makefile for building RPi5 Linux Firmware

# --- Configuration ---

# Target Architecture
ARCH := arm64

# Cross Compiler Prefix (MUST BE SET BY USER VIA COMMAND LINE)
# Example: make CROSS_COMPILE=aarch64-none-linux-gnu- ...
# Ensure toolchain path is correct or in PATH.
CROSS_COMPILE ?=

# Kernel Version (Using a recent RPi tag)
# Find tags at: https://github.com/raspberrypi/linux/tags
KERNEL_TAG ?= rp-6.6.y # Use a branch/tag like rp-6.6.y or a specific tag like 1.20240529
KERNEL_DIR_NAME := linux-$(KERNEL_TAG) # Simplified dir name
KERNEL_TARBALL := $(KERNEL_TAG).tar.gz
KERNEL_URL := https://github.com/raspberrypi/linux/archive/refs/tags/$(KERNEL_TAG).tar.gz

# Build Directory
BUILD_DIR := $(shell pwd)/build
KERNEL_SRC := $(BUILD_DIR)/$(KERNEL_DIR_NAME)
KERNEL_OUT := $(BUILD_DIR)/kernel_out

# QEMU Command (System emulation for AArch64)
QEMU_CMD ?= qemu-system-aarch64

# Output Kernel Image (Uncompressed Image for QEMU simplicity first)
KERNEL_IMAGE := $(KERNEL_OUT)/arch/$(ARCH)/boot/Image


# --- Tool Check ---

# Defer strict tool check until a build target is invoked

# Function to check tools just before build
define check_tools
	$(eval CC := $(CROSS_COMPILE)gcc)
	$(info --- Checking Tools ---)
	$(info Using CROSS_COMPILE prefix: [$(CROSS_COMPILE)])
	@if [ -z "$(CROSS_COMPILE)" ]; then \
		printf >&2 "\n\033[1;31mERROR: CROSS_COMPILE variable is not set.\033[0m\n"; \
		printf >&2 "Please set it via the command line or environment to your AArch64 toolchain prefix.\n"; \
		printf >&2 "Example: make CROSS_COMPILE=aarch64-unknown-linux-gnu- build-kernel\n\n"; \
		exit 1; \
	fi
	@if ! command -v $(CC) &> /dev/null; then \
		echo "ERROR: Compiler $(CC) not found."; \
		echo "Check CROSS_COMPILE prefix and toolchain installation/PATH."; \
		exit 1; \
	else \
		echo "Compiler found: $$(command -v $(CC))"; \
		$$( $(CC) --version ); \
	fi
	@if ! command -v $(QEMU_CMD) &> /dev/null; then \
		echo "WARNING: QEMU command $(QEMU_CMD) not found. 'make run-qemu' will fail."; \
		echo "Install QEMU for AArch64 system emulation (e.g., 'brew install qemu')."; \
	else \
		echo "QEMU found: $$(command -v $(QEMU_CMD))"; \
		$$( $(QEMU_CMD) --version ); \
	fi
	@echo "--- Tool Check Done ---"
endef


# --- Targets ---

.PHONY: all download-kernel extract-kernel configure-kernel build-kernel run-qemu clean help

# Default target
all: build-kernel

help:
	@echo "Makefile Targets:"
	@echo "  download-kernel  - Download the Linux kernel source tarball"
	@echo "  extract-kernel   - Extract the Linux kernel source"
	@echo "  configure-kernel - Configure the kernel (uses bcm2712_defconfig for RPi5)"
	@echo "  build-kernel     - Build the kernel Image"
	@echo "  run-qemu         - Run the built kernel in QEMU (will panic without rootfs)"
	@echo "  clean            - Remove built files"
	@echo "  help             - Show this help message"
	@echo ""
	@echo "Usage Example:"
	@echo "  make CROSS_COMPILE=aarch64-none-linux-gnu- all"
	@echo ""
	@echo "Current Configuration (can be overridden):"
	@echo "  ARCH           = $(ARCH)"
	@echo "  KERNEL_TAG     = $(KERNEL_TAG)"
	@echo "  QEMU_CMD       = $(QEMU_CMD)"
	@echo "  CROSS_COMPILE  = $(CROSS_COMPILE) (MUST be set)"


# Download Kernel Tarball
$(BUILD_DIR)/$(KERNEL_TARBALL):
	@echo "--- Downloading Kernel $(KERNEL_TAG) ---"
	@mkdir -p $(BUILD_DIR)
	wget -O $@ $(KERNEL_URL)

download-kernel: $(BUILD_DIR)/$(KERNEL_TARBALL)

# Extract Kernel Source
# Depends on download, ensures source dir exists
$(KERNEL_SRC)/Makefile: $(BUILD_DIR)/$(KERNEL_TARBALL)
	@echo "--- Extracting Kernel ---"
	@mkdir -p $(BUILD_DIR)
	# Remove old dir if it exists to ensure clean extraction
	rm -rf $(KERNEL_SRC)
	tar -zxf $(BUILD_DIR)/$(KERNEL_TARBALL) -C $(BUILD_DIR)
	# Ensure the directory name matches what tar extracts
	@if [ ! -d "$(KERNEL_SRC)" ]; then \
		EXTRACTED_DIR=$$(tar -tzf $(BUILD_DIR)/$(KERNEL_TARBALL) | head -n 1 | cut -f1 -d"/"); \
		if [ -n "$$EXTRACTED_DIR" ] && [ "$$EXTRACTED_DIR" != "." ]; then \
			mv "$(BUILD_DIR)/$$EXTRACTED_DIR" "$(KERNEL_SRC)"; \
		else \
			echo "ERROR: Could not determine extracted directory name from tarball."; \
			exit 1; \
		fi \
	fi
	@touch -c $@ # Update timestamp

extract-kernel: $(KERNEL_SRC)/Makefile

# Configure Kernel (Using RPi5 defconfig)
$(KERNEL_OUT)/.config: $(KERNEL_SRC)/Makefile
	$(call check_tools)
	@echo "--- Configuring Kernel (using bcm2712_defconfig) ---"
	@mkdir -p $(KERNEL_OUT)
	$(MAKE) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) bcm2712_defconfig

configure-kernel: $(KERNEL_OUT)/.config

# Build Kernel Image (Building uncompressed Image first)
$(KERNEL_IMAGE): $(KERNEL_OUT)/.config
	$(call check_tools)
	@echo "--- Building Kernel Image ---"
	# Use nproc (Linux), fallback to sysctl (macOS), fallback to 1 core
	$(MAKE) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) -j$$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 1) Image modules

# Build target depends on the image
build-kernel: $(KERNEL_IMAGE)

# Run in QEMU
run-qemu: $(KERNEL_IMAGE)
	$(call check_tools)
	@echo "--- Running Kernel in QEMU ---"
	@echo "NOTE: This will likely kernel panic as no root filesystem is provided."
	$(QEMU_CMD) \
		-M virt \
		-cpu cortex-a72 \
		-smp 4 \
		-m 1024 \
		-kernel $(KERNEL_IMAGE) \
		-append "console=ttyAMA0 root=/dev/vda nokaslr" \
		-nographic \
		-serial stdio

# Clean up
clean:
	@echo "--- Cleaning ---"
	rm -rf $(BUILD_DIR)
