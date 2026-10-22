#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "$0")" && pwd -P)
mode=desktop
case "${1:-}" in
    '') ;;
    --desktop) mode=desktop ;;
    --headless) mode=headless ;;
    *) echo "Usage: $0 [--desktop|--headless]" >&2; exit 2 ;;
esac

(( EUID != 0 )) || {
    echo 'Run install.sh as a regular user; the script will request privileges when needed.' >&2
    exit 1
}

if [[ "$mode" == desktop ]]; then
    command -v pkexec >/dev/null || {
        echo 'Desktop mode requires pkexec (pkexec package) and an active polkit authentication agent.' >&2
        exit 1
    }
    pkexec "$repo_dir/scripts/install-root.sh" --user-uid "$(id -u)" --desktop
    systemctl --user daemon-reload
    systemctl --user enable --now fortivpn-otp-agent.service
    if command -v zenity >/dev/null && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
        zenity --info --title='fortivpn-sgcan' --width=520 \
            --text='Installation complete. Open "fortivpn-sgcan" from the application menu.'
    else
        echo 'Installation complete. Run fortivpn-manager.'
    fi
else
    command -v sudo >/dev/null || {
        echo 'Headless mode requires sudo.' >&2
        exit 1
    }
    sudo "$repo_dir/scripts/install-root.sh" --user-uid "$(id -u)" --headless
    echo 'Installation complete. Run: fortivpn-cli add'
fi
