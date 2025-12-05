#!/bin/sh
# Force include passdev binary for passdev-failover wrapper

# Standard Header for initramfs-tools (See man 7 initramfs-tools)
# https://manpages.ubuntu.com/manpages/noble/en/man7/initramfs-tools.7.html#hook%20scripts

PREREQ=""

prereqs()
{
    echo "$PREREQ"
}

case $1 in
prereqs)
    prereqs
    exit 0
    ;;
esac

# Source the hook helper functions
. /usr/share/initramfs-tools/hook-functions

# Logic: Explicitly copy the passdev binary
# copy_exec source [target]
# We look for the binary in standard locations to be safe across usrmerge changes
if [ -x /lib/cryptsetup/scripts/passdev ]; then
    copy_exec /lib/cryptsetup/scripts/passdev /lib/cryptsetup/scripts/passdev
elif [ -x /usr/lib/cryptsetup/scripts/passdev ]; then
    # Even if it lives in /usr/lib on host, map it to /lib inside initramfs for consistency
    copy_exec /usr/lib/cryptsetup/scripts/passdev /lib/cryptsetup/scripts/passdev
else
    echo "ERROR: force-passdev hook could not find passdev binary!" >&2
    exit 1
fi

