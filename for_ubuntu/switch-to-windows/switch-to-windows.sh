#!/bin/bash
set -Eeuo pipefail

notify_error() {
    local message=$1
    printf '%s\n' "Switch to Windows: $message" >&2
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Switch to Windows" "$message" >/dev/null 2>&1 || true
    fi
}

if [[ ${EUID} -ne 0 ]]; then
    if ! command -v pkexec >/dev/null 2>&1; then
        notify_error 'This launcher needs pkexec or sudo.'
        exit 1
    fi
    exec pkexec "$0" "$@"
fi

for command_name in awk grub-editenv systemctl; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        notify_error "Required command is not installed: $command_name"
        exit 1
    fi
done

if [[ ! -r /boot/grub/grub.cfg ]]; then
    notify_error 'Cannot read /boot/grub/grub.cfg.'
    exit 1
fi

# Find the first Windows menu entry. The awk keeps track of the enclosing
# submenu, if os-prober emits Windows as a nested entry.
ENTRY=$(/usr/bin/awk -F"'" '
    /^[[:space:]]*submenu[[:space:]]+/ { submenu=$2; next }
    $1 ~ /^[[:space:]]*menuentry[[:space:]]+/ && tolower($2) ~ /windows/ {
        title=$2
        if (submenu != "") {
            title = submenu ">" title
        }
        print title
        exit
    }
    /^[[:space:]]*}[[:space:]]*$/ { submenu=""; next }
' /boot/grub/grub.cfg)

if [[ -z ${ENTRY:-} ]]; then
    notify_error 'No Windows menuentry was found in /boot/grub/grub.cfg. Ensure os-prober is enabled and run sudo update-grub.'
    exit 1
fi

# grub-reboot alone is ignored when GRUB_DEFAULT is not "saved". A private
# grubenv variable is therefore used and is consumed by our custom grub.d hook.
/usr/bin/grub-editenv /boot/grub/grubenv set "switch_to_windows_entry=$ENTRY"

if ! /usr/bin/grub-editenv /boot/grub/grubenv list | /usr/bin/grep -Fq "switch_to_windows_entry=$ENTRY"; then
    notify_error 'Failed to save the one-shot Windows boot selection.'
    exit 1
fi

sync

# Ignore all inhibitors.
systemctl reboot -i