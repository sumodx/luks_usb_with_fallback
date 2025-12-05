#!/bin/sh
# Wrapper script: Try passdev (USB), fall back to askpass (Keyboard)

# 1. Protection against 'set -e' killing the script on failure
set +e

# 2. Try passdev. 
# - We pass "$@" to forward arguments (device, path, timeout).
# - We DO NOT capture stdout. It flows naturally to cryptsetup (Binary Safe).
# - The '&& exit 0' ensures we quit immediately if successful.
/lib/cryptsetup/scripts/passdev "$@" && exit 0

# 3. Fallback: If we are here, passdev failed (USB missing or timeout).
/lib/cryptsetup/askpass "USB Key missing. Enter Passphrase: "
exit 0

