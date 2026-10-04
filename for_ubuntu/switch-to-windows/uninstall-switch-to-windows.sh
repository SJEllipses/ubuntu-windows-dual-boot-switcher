#!/bin/bash
set -Eeuo pipefail

die() {
    printf '%s\n' "uninstall-switch-to-windows.sh: $*" >&2
    exit 1
}

if [[ ${EUID} -ne 0 ]]; then
    if ! command -v sudo >/dev/null 2>&1; then
        die 'please run it with sudo: sudo bash uninstall-switch-to-windows.sh'
    fi
    exec sudo /bin/bash "$0" "$@"
fi

# Stop the service before removing the ESP flag and helper.
if [[ -f /etc/systemd/system/clear-boot-once-flag.service ]]; then
    systemctl disable --now clear-boot-once-flag.service
fi
systemctl reset-failed clear-boot-once-flag.service >/dev/null 2>&1 || true
rm -f -- \
    /etc/systemd/system/clear-boot-once-flag.service \
    /usr/local/sbin/clear-switch-to-ubuntu-flag \
    /usr/local/bin/switch-to-windows \
    /usr/local/share/icons/switch-to-windows.png \
    /usr/share/applications/switch-to-windows.desktop
systemctl daemon-reload

# Clean one-shot state that would otherwise affect the next boot.
if command -v grub-editenv >/dev/null 2>&1; then
    if /usr/bin/grub-editenv /boot/grub/grubenv list 2>/dev/null | grep -q '^switch_to_windows_entry='; then
        /usr/bin/grub-editenv /boot/grub/grubenv unset switch_to_windows_entry
    fi
fi
if /usr/bin/findmnt -n /boot/efi >/dev/null 2>&1; then
    rm -f -- /boot/efi/EFI/ubuntu/switch.flag
fi

# Remove helpers installed by this project. Unrelated /etc/grub.d files,
# including unrelated 42_* scripts, are not touched.
removed_helpers=0
for helper in /etc/grub.d/*_switch_boot_once; do
    if [[ -e $helper ]]; then
        rm -f -- "$helper"
        echo "Removed GRUB helper: $helper"
        removed_helpers=1
    fi
done

# Regenerate grub.cfg so the one-shot default/timeout snippet disappears.
if command -v update-grub >/dev/null 2>&1; then
    update-grub
else
    die 'update-grub is required to regenerate grub.cfg after removing the helper.'
fi

if grep -Fq 'SWITCH_BOOT_ONCE_MARKER' /boot/grub/grub.cfg; then
    die 'the custom GRUB marker is still present in /boot/grub/grub.cfg.'
fi

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database /usr/share/applications
fi

# The installer copies uninstall-switch-to-windows.sh to this system command.
if [[ ${BASH_SOURCE[0]} == /usr/local/sbin/uninstall-switch-to-windows ]]; then
    rm -f -- "$BASH_SOURCE"
fi

echo 'Switch-to-Windows/Ubuntu one-shot boot helpers were uninstalled.'
if (( removed_helpers == 0 )); then
    echo 'No project GRUB helper had been present; other installed files were still cleaned.'
fi