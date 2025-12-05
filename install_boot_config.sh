#!/bin/bash
# Safety: Stop on error
set -e

echo "Deploying system-critical boot scripts..."

# 1. Deploy the Failover Script (The Wrapper)
# Source: has .sh (for your editing convenience)
# Destination: NO .sh (standard system binary convention)
sudo install -m 0755 -o root -g root \
    ./passdev-failover.sh \
    /lib/cryptsetup/scripts/passdev-failover

# 2. Deploy the Initramfs Hook (The Force-Include)
# Source: has .sh
# Destination: NO .sh (MANDATORY for run-parts execution)
sudo install -m 0755 -o root -g root \
    ./force-passdev-hook.sh \
    /etc/initramfs-tools/hooks/force-passdev

# 3. Regenerate the Boot Image
echo "Regenerating initramfs..."
sudo update-initramfs -u

echo "Deployment complete."
echo "Verify hook execution by checking if the binary is in the image:"
echo "Expect:"
echo "- usr/lib/cryptsetup/scripts/passdev"
echo "- usr/lib/cryptsetup/scripts/passdev-failover"
sudo lsinitramfs /boot/initrd.img-$(uname -r) | grep "cryptsetup/scripts/passdev"
