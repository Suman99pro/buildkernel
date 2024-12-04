#!/bin/bash

# Script to download, compile, and install a new Linux kernel
set -e

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use sudo." >&2
  exit 1
fi

# Detect the distribution type
echo "Detecting distribution..."
if [[ -f /etc/debian_version ]]; then
  DISTRO="debian"
elif [[ -f /etc/redhat-release ]]; then
  DISTRO="fedora"
else
  echo "Unsupported distribution. This script supports Debian and Fedora-based systems." >&2
  exit 1
fi
echo "Detected $DISTRO-based distribution."

# Prompt the user for the kernel version
read -rp "Enter the Linux kernel version you want to install (e.g., 6.6): " KERNEL_VERSION

# Variables
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VERSION}.tar.xz"
NUM_CORES=$(nproc) # Automatically detect the number of processor cores

# Install required dependencies
echo "Installing required dependencies..."
if [[ $DISTRO == "debian" ]]; then
  apt-get update -y
  apt-get install -y build-essential libncurses-dev bison flex libssl-dev libelf-dev wget
elif [[ $DISTRO == "fedora" ]]; then
  dnf install -y gcc make ncurses-devel bison flex elfutils-libelf-devel openssl-devel wget
  dnf groupinstall -y "Development Tools"
fi

# Download the kernel source
echo "Downloading Linux kernel version ${KERNEL_VERSION}..."
cd /usr/src
if [[ ! -f linux-${KERNEL_VERSION}.tar.xz ]]; then
  wget ${KERNEL_URL} || { echo "Failed to download kernel. Check the version or URL."; exit 1; }
fi

# Extract the kernel source
echo "Extracting kernel source..."
tar -xf linux-${KERNEL_VERSION}.tar.xz
cd linux-${KERNEL_VERSION}

# Clean previous build files (if any)
echo "Cleaning build environment..."
make mrproper

# Configure the kernel
echo "Configuring the kernel..."
make defconfig # Use default config; change to 'menuconfig' for interactive configuration

# Compile the kernel
echo "Compiling the kernel (this may take a while)..."
make -j${NUM_CORES} V=1 > /usr/src/build_output.log 2>&1 || {
  echo "Kernel compilation failed. Check /usr/src/build_output.log for details.";
  exit 1;
}

# Install the kernel modules
echo "Installing kernel modules..."
make modules_install

# Install the kernel
echo "Installing the kernel..."
make install

# Update GRUB bootloader
echo "Updating GRUB bootloader..."
if [[ $DISTRO == "debian" ]]; then
  update-grub
elif [[ $DISTRO == "fedora" ]]; then
  grub2-mkconfig -o /boot/grub2/grub.cfg
fi

# Ensure locale is set to prevent encoding issues
echo "Setting locale to avoid encoding issues..."
export LANG=C
export LC_ALL=C

# Inform the user about reboot
echo "Kernel version ${KERNEL_VERSION} has been installed. Reboot to use the new kernel."
