# Ubuntu LUKS USB Auto-Unlock with Failover

## Overview
This configuration enables an Ubuntu 24.04 Server/Desktop (Encrypted Root via LUKS) to:
1.  **Auto-Unlock**: Attempt to unlock the root partition automatically using a keyfile on a specific USB drive during boot.
2.  **Failover Gracefully**: If the USB drive is missing or fails to mount within 30 seconds, immediately drop to the standard password prompt.

## Architecture & Design Decisions
We utilize a custom wrapper approach rather than the standard `passdev` implementation to solve specific architectural limitations in Ubuntu/Debian:

1.  **The "Failover" Logic**: 
    *   Standard `passdev` simply fails or hangs if the device is missing.
    *   **Our Solution**: `passdev-failover.sh`. This wrapper runs `passdev`; if it returns a non-zero exit code (missing USB), it explicitly calls `/lib/cryptsetup/askpass` to request the password manually.

2.  **The "Missing Binary" Problem**:
    *   When the `keyscript=` option in `/etc/crypttab` is changed to our custom wrapper, the initramfs generator no longer detects that it needs the original `passdev` binary.
    *   **Our Solution**: `force-passdev-hook.sh`. An initramfs hook that explicitly copies the native `passdev` binary and its dependencies into the boot image.

3.  **Systemd vs. Initramfs Conflict**:
    *   Systemd does not understand the `device:path` syntax used by `passdev` and will hang indefinitely waiting for a device node that looks like a file path.
    *   **Our Solution**: Using `noauto` (to stop Systemd) combined with `initramfs` (to force inclusion in the bootloader) in `/etc/crypttab`.

## Repository Contents
*   `passdev-failover.sh`: The wrapper script used as the keyscript.
*   `force-passdev-hook.sh`: The hook ensuring the binary exists in the boot image.
*   `install_boot_config.sh`: Automated installer to place files in system directories with correct permissions.

---

## Installation Procedure

### Prerequisites
*   A USB drive (WARNING: specific partition will be formatted). Or you could bring a pre-formatted drive and skip the formatting steps below.
*   Root access to the server.
*   LVM on LUKS installation.

### Step 1: Prepare the USB Drive & Key
*Replace `/dev/sdb1` with your actual USB partition, check using `lsblk`.*

1.  **Format with Label**: The label is crucial for stable detection.
    ```bash
    sudo mkfs.ext4 -L "test" /dev/sdb1
    ```
    * Can use any filesystem type that is supported including FAT32. Ubuntu 24.04 Server mininimized does not include `dosfstools` package to format it, so you can do it on any other system or apt install the tools.
    * Label can be anything, just ensure that if you have a second backup usb-drive with the key it has the same label. That way it will just auto-mount without needing to drop into init shell and mess with crypttab. In case you forget label, no worries just look at crypttab and either set the label, or update the crypttab to use the new label.

2.  **Generate Keyfile**:
    ```bash
    sudo mkdir -p /mnt/usb
    sudo mount /dev/disk/by-label/test /mnt/usb
    sudo dd if=/dev/urandom of=/mnt/usb/kiwi_key.bin bs=512 count=8
    sudo chmod 400 /mnt/usb/kiwi_key.bin
    ```
3.  **Enroll Key in LUKS**:
    ```bash
    # Replace /dev/sda4 with your encrypted root partition
    sudo cryptsetup luksAddKey /dev/sda4 /mnt/usb/kiwi_key.bin
    sudo umount /mnt/usb
    ```

### Step 2: Configure Crypttab
You must edit the system configuration to use the new scripts.

1.  Get your partition UUID:
    ```bash
    sudo blkid -t TYPE=crypto_LUKS -s UUID -o value
    ```
2.  Edit `/etc/crypttab`:
    ```bash
    sudo nano /etc/crypttab
    ```
3.  Update the line for your root device to match this format exactly. The actual values should be what you put on your system in the steps above for root partition UUID, label, key file path:
    
    ```text
    dm_crypt-0 UUID=<YOUR-UUID> /dev/disk/by-label/test:/kiwi_key.bin:30 luks,keyscript=/lib/cryptsetup/scripts/passdev-failover,noauto,initramfs
    ```

    **Critical Flags Explanation**:
    *   `:30`: 30-second timeout for USB detection.
    *   `keyscript=...`: Points to our wrapper (installed in Step 3).
    *   `noauto`: Prevents Systemd boot hang.
    *   `initramfs`: Forces Initramfs to process the drive despite `noauto`.

### Step 3: Deploy Scripts & Update Boot Image
Run the provided installer to place the scripts in `/lib` and `/etc` and regenerate the initramfs.

```bash
cd ~/boot_config_scripts
chmod +x install_boot_config.sh
./install_boot_config.sh
```

**Note**: The installer handles:
*   Stripping `.sh` extensions where required by system rules (`run-parts`).
*   Setting `root:root` ownership and `0755` permissions.
*   Running `update-initramfs -u`.

### Step 4: Verification
Before rebooting, ensure the scripts and binaries are actually inside the generated image:

```bash
sudo lsinitramfs /boot/initrd.img-$(uname -r) | grep "cryptsetup/scripts/passdev"
```

**Required Output**: You must see *both* lines below (paths may vary slightly):
*   `usr/lib/cryptsetup/scripts/passdev`
*   `usr/lib/cryptsetup/scripts/passdev-failover`

---

## Testing

1.  **Auto-Unlock**: Insert USB, Reboot. System should boot without interaction.
2.  **Failover**: Remove USB, Reboot. System should wait 30 seconds, then display:
    `USB Key missing. Enter Passphrase:`
```
