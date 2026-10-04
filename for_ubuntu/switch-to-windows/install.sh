#!/bin/bash
set -Eeuo pipefail

die() {
    printf '%s\n' "install.sh: $*" >&2
    exit 1
}

if [[ ${EUID} -ne 0 ]]; then
    die 'please run it with sudo: sudo ./install.sh'
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
for required_file in \
    grub_switch_once \
    clear-switch-to-ubuntu-flag \
    clear-boot-once-flag.service \
    switch-to-windows.sh \
    uninstall-switch-to-windows.sh \
    switch-to-windows.desktop \
    windows.png
do
    [[ -f "$SCRIPT_DIR/$required_file" ]] || die "missing source file: $required_file"
done

command -v update-grub >/dev/null 2>&1 || die 'update-grub is required.'
command -v systemctl >/dev/null 2>&1 || die 'systemctl is required.'

if ! /usr/bin/findmnt -n /boot/efi >/dev/null; then
    die '/boot/efi is not mounted; mount the Ubuntu ESP first.'
fi
if [[ ! -d /boot/efi/EFI/ubuntu ]]; then
    die '/boot/efi/EFI/ubuntu does not exist; this installer expects a standard Ubuntu ESP layout.'
fi

find_entry() {
    local pattern=$1
    /usr/bin/awk -F"'" -v pattern="$pattern" '
        /^[[:space:]]*submenu[[:space:]]+/ { submenu=$2; next }
        $1 ~ /^[[:space:]]*menuentry[[:space:]]+/ && tolower($2) ~ pattern {
            title=$2
            if (submenu != "") {
                title = submenu ">" title
            }
            print title
            exit
        }
        /^[[:space:]]*}[[:space:]]*$/ { submenu=""; next }
    ' /boot/grub/grub.cfg
}

UBUNTU_ENTRY=$(find_entry '^ubuntu')
[[ -n $UBUNTU_ENTRY ]] || die 'could not find an Ubuntu menuentry in /boot/grub/grub.cfg.'
WINDOWS_ENTRY=$(find_entry 'windows')
[[ -n $WINDOWS_ENTRY ]] || die 'could not find a Windows menuentry; enable os-prober and run sudo update-grub first.'

# Do not stack multiple copies of this helper. Uninstall first when upgrading.
if compgen -G '/etc/grub.d/*_switch_boot_once' >/dev/null; then
    die 'a switch-boot-once helper is already installed; run sudo /usr/local/sbin/uninstall-switch-to-windows first.'
fi
# Allocate the first free two-digit numeric prefix. GRUB runs these scripts in
# lexical order, so any number after 40_custom can override default/timeout.
script_number=42
while compgen -G "/etc/grub.d/${script_number}_*" >/dev/null; do
    script_number=$((script_number + 1))
done
if (( script_number > 99 )); then
    die 'no free numeric prefix from 42 through 99 in /etc/grub.d.'
fi
grub_helper="/etc/grub.d/${script_number}_switch_boot_once"
echo "Installing GRUB helper as $grub_helper"

install -m 0755 "$SCRIPT_DIR/grub_switch_once" "$grub_helper"
install -m 0755 "$SCRIPT_DIR/clear-switch-to-ubuntu-flag" /usr/local/sbin/clear-switch-to-ubuntu-flag
install -m 0644 "$SCRIPT_DIR/clear-boot-once-flag.service" /etc/systemd/system/clear-boot-once-flag.service
install -m 0755 "$SCRIPT_DIR/switch-to-windows.sh" /usr/local/bin/switch-to-windows
install -m 0755 "$SCRIPT_DIR/uninstall-switch-to-windows.sh" /usr/local/sbin/uninstall-switch-to-windows
install -D -m 0644 "$SCRIPT_DIR/windows.png" /usr/local/share/icons/switch-to-windows.png
install -m 0644 "$SCRIPT_DIR/switch-to-windows.desktop" /usr/share/applications/switch-to-windows.desktop
# grub_switch_once reads the previous grub.cfg while update-grub is writing its
# replacement, so its generated title remains synchronized after kernel updates.
update-grub

if ! grep -Fq 'SWITCH_BOOT_ONCE_MARKER' /boot/grub/grub.cfg; then
    die 'update-grub completed, but the custom one-shot helper was not emitted into grub.cfg.'
fi

systemctl daemon-reload
systemctl enable --now clear-boot-once-flag.service

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database /usr/share/applications
fi

printf '%s\n' \
    'Ubuntu side installed successfully.' \
    "Normal GRUB timeout/default behavior is unchanged." \
    "Windows->Ubuntu helper: $grub_helper" \
    'Ubuntu->Windows launcher: /usr/share/applications/switch-to-windows.desktop' \
    'Uninstall command: sudo /usr/local/sbin/uninstall-switch-to-windows'