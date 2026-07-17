#!/usr/bin/env bash

set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
stamp="$(date +%Y%m%d-%H%M%S)"
backup="$HOME/.local/state/windows11-rice/backups/$stamp"

assume_yes=false
case "${1:-}" in
    --yes|-y) assume_yes=true ;;
    "") ;;
    *) printf 'usage: %s [--yes]\n' "$0" >&2; exit 2 ;;
esac

dependencies=(
    hyprctl quickshell waybar rofi rg jq python3 yad awww grim slurp wl-copy
    hyprlock thunar kitty fastfetch iwctl bluetoothctl pavucontrol playerctl
    brightnessctl satty notify-send magick wpctl pactl
)

missing_commands() {
    local command
    for command in "${dependencies[@]}"; do
        command -v "$command" >/dev/null 2>&1 || printf '%s\n' "$command"
    done
}

detect_package_manager() {
    if [[ -e /etc/NIXOS ]] && command -v nix >/dev/null 2>&1; then
        printf 'nix\n'
        return
    fi
    local manager
    for manager in pacman apt-get dnf zypper xbps-install apk nix; do
        if command -v "$manager" >/dev/null 2>&1; then
            printf '%s\n' "$manager"
            return
        fi
    done
    return 1
}

run_as_root() {
    if ((EUID == 0)); then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    elif command -v doas >/dev/null 2>&1; then
        doas "$@"
    else
        printf 'Need sudo, doas, or a root shell to install system packages.\n' >&2
        return 1
    fi
}

native_package_for() {
    local manager="$1" command="$2"
    case "$manager:$command" in
        *:hyprctl) printf 'hyprland\n' ;;
        pacman:python3) printf 'python\n' ;;
        pacman:rofi) printf 'rofi-wayland\n' ;;
        pacman:wl-copy) printf 'wl-clipboard\n' ;;
        pacman:bluetoothctl) printf 'bluez-utils\n' ;;
        pacman:notify-send) printf 'libnotify\n' ;;
        pacman:magick) printf 'imagemagick\n' ;;
        pacman:wpctl) printf 'wireplumber\n' ;;
        pacman:pactl) printf 'libpulse\n' ;;
        apt-get:wl-copy) printf 'wl-clipboard\n' ;;
        apt-get:bluetoothctl) printf 'bluez\n' ;;
        apt-get:notify-send) printf 'libnotify-bin\n' ;;
        apt-get:magick) printf 'imagemagick\n' ;;
        apt-get:wpctl) printf 'wireplumber\n' ;;
        apt-get:pactl) printf 'pulseaudio-utils\n' ;;
        dnf:rofi) printf 'rofi-wayland\n' ;;
        dnf:wl-copy) printf 'wl-clipboard\n' ;;
        dnf:bluetoothctl) printf 'bluez\n' ;;
        dnf:notify-send) printf 'libnotify\n' ;;
        dnf:magick) printf 'ImageMagick\n' ;;
        dnf:wpctl) printf 'wireplumber-utils\n' ;;
        dnf:pactl) printf 'pulseaudio-utils\n' ;;
        zypper:wl-copy) printf 'wl-clipboard\n' ;;
        zypper:bluetoothctl) printf 'bluez\n' ;;
        zypper:notify-send) printf 'libnotify-tools\n' ;;
        zypper:magick) printf 'ImageMagick\n' ;;
        zypper:wpctl) printf 'wireplumber-tools\n' ;;
        zypper:pactl) printf 'libpulse-tools\n' ;;
        xbps-install:python3) printf 'python3\n' ;;
        xbps-install:wl-copy) printf 'wl-clipboard\n' ;;
        xbps-install:bluetoothctl) printf 'bluez\n' ;;
        xbps-install:notify-send) printf 'libnotify\n' ;;
        xbps-install:magick) printf 'ImageMagick\n' ;;
        xbps-install:wpctl) printf 'wireplumber\n' ;;
        xbps-install:pactl) printf 'pulseaudio-utils\n' ;;
        apk:wl-copy) printf 'wl-clipboard\n' ;;
        apk:bluetoothctl) printf 'bluez\n' ;;
        apk:notify-send) printf 'libnotify\n' ;;
        apk:magick) printf 'imagemagick\n' ;;
        apk:wpctl) printf 'wireplumber\n' ;;
        apk:pactl) printf 'pulseaudio-utils\n' ;;
        *) printf '%s\n' "$command" ;;
    esac
}

nix_package_for() {
    case "$1" in
        hyprctl) printf 'hyprland\n' ;;
        rofi) printf 'rofi-wayland\n' ;;
        rg) printf 'ripgrep\n' ;;
        wl-copy) printf 'wl-clipboard\n' ;;
        thunar) printf 'xfce.thunar\n' ;;
        bluetoothctl) printf 'bluez\n' ;;
        notify-send) printf 'libnotify\n' ;;
        magick) printf 'imagemagick\n' ;;
        wpctl) printf 'wireplumber\n' ;;
        pactl) printf 'pulseaudio\n' ;;
        *) printf '%s\n' "$1" ;;
    esac
}

install_native_package() {
    local manager="$1" package="$2"
    case "$manager" in
        pacman) run_as_root pacman -S --needed --noconfirm "$package" ;;
        apt-get) run_as_root apt-get install -y "$package" ;;
        dnf) run_as_root dnf install -y "$package" ;;
        zypper) run_as_root zypper --non-interactive install "$package" ;;
        xbps-install) run_as_root xbps-install -Sy "$package" ;;
        apk) run_as_root apk add "$package" ;;
        nix) nix profile add "nixpkgs#$package" ;;
        *) return 1 ;;
    esac
}

mapfile -t missing < <(missing_commands)
if ((${#missing[@]})); then
    printf 'Missing dependencies:\n'
    printf '  %s\n' "${missing[@]}"

    manager="$(detect_package_manager || true)"
    if [[ -z "$manager" ]]; then
        printf 'No supported package manager found.\n' >&2
        exit 1
    fi

    if ! $assume_yes; then
        if [[ ! -t 0 ]]; then
            printf 'Run this installer interactively or pass --yes.\n' >&2
            exit 1
        fi
        read -r -p "Install missing dependencies with $manager? [Y/n] " answer
        [[ "${answer:-y}" =~ ^[Yy]$ ]] || exit 0
    fi

    if [[ "$manager" == apt-get ]]; then
        run_as_root apt-get update
    fi

    for command in "${missing[@]}"; do
        if [[ "$manager" == nix ]]; then
            package="$(nix_package_for "$command")"
        else
            package="$(native_package_for "$manager" "$command")"
        fi
        printf 'Installing %s (provides %s)...\n' "$package" "$command"
        install_native_package "$manager" "$package" || \
            printf 'Warning: %s could not install %s.\n' "$manager" "$package" >&2
    done

    export PATH="$HOME/.nix-profile/bin:$PATH"
    hash -r

    # Point-release distro repositories often lack Quickshell or current Hypr
    # packages. If Nix is already available, use it only for anything that the
    # native package manager could not provide.
    if [[ "$manager" != nix ]] && command -v nix >/dev/null 2>&1; then
        mapfile -t still_missing < <(missing_commands)
        for command in "${still_missing[@]}"; do
            package="$(nix_package_for "$command")"
            printf 'Trying Nix fallback for %s...\n' "$command"
            nix profile add "nixpkgs#$package" || true
        done
        hash -r
    fi

    mapfile -t missing < <(missing_commands)
    if ((${#missing[@]})); then
        printf 'Still missing after installation:\n' >&2
        printf '  %s\n' "${missing[@]}" >&2
        printf 'Your distribution does not provide every required package.\n' >&2
        exit 1
    fi
else
    printf 'All dependencies are already installed.\n'
fi

mkdir -p \
    "$backup/config/quickshell" \
    "$backup/config/waybar" \
    "$HOME/.config" \
    "$HOME/.local/bin" \
    "$HOME/.local/share/windows11/wallpapers"

[[ -e "$HOME/.config/hypr" ]] && cp -a -- "$HOME/.config/hypr" "$backup/config/"
[[ -e "$HOME/.config/quickshell/windows11" ]] && \
    cp -a -- "$HOME/.config/quickshell/windows11" "$backup/config/quickshell/"
[[ -e "$HOME/.config/waybar/windows11" ]] && \
    cp -a -- "$HOME/.config/waybar/windows11" "$backup/config/waybar/"
[[ -e "$HOME/.config/fastfetch" ]] && cp -a -- "$HOME/.config/fastfetch" "$backup/config/"

# The switcher needs a clean copy of whatever desktop the user had before this.
original="$HOME/.config/hypr/profiles/original"
if [[ ! -d "$original" && -d "$HOME/.config/hypr/config" ]]; then
    mkdir -p "$original"
    [[ -f "$HOME/.config/hypr/colors.conf" ]] && cp -- "$HOME/.config/hypr/colors.conf" "$original/colors.conf"
    cp -a -- "$HOME/.config/hypr/config" "$original/config"
fi

mkdir -p \
    "$HOME/.config/hypr/config" \
    "$HOME/.config/hypr/profiles" \
    "$HOME/.config/fastfetch" \
    "$HOME/.config/quickshell" \
    "$HOME/.config/waybar" \
    "$HOME/.config/windows11"

cp -a -- "$repo/config/hypr/profiles/windows11" "$HOME/.config/hypr/profiles/"
cp -a -- "$repo/config/quickshell/windows11" "$HOME/.config/quickshell/"
cp -a -- "$repo/config/waybar/windows11" "$HOME/.config/waybar/"
cp -- "$repo/config/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
cp -- "$repo/config/hypr/hyprland.conf" "$HOME/.config/hypr/hyprland.conf"
cp -- "$repo/config/hypr/hyprlock-windows.conf" "$HOME/.config/hypr/hyprlock-windows.conf"
cp -- "$repo/local/bin/"* "$HOME/.local/bin/"
cp -- "$repo/share/wallpapers/"* "$HOME/.local/share/windows11/wallpapers/"

if [[ ! -f "$HOME/.config/windows11/location.json" ]]; then
    cp -- "$repo/config/windows11/location.json" "$HOME/.config/windows11/location.json"
fi

# Repository files use a token where QML and Waybar cannot expand $HOME.
for path in \
    "$HOME/.config/hypr/hyprlock-windows.conf" \
    "$HOME/.config/hypr/profiles/windows11" \
    "$HOME/.config/quickshell/windows11" \
    "$HOME/.config/waybar/windows11" \
    "$HOME/.local/bin"/windows-*; do
    [[ -e "$path" ]] || continue
    if [[ -d "$path" ]]; then
        while IFS= read -r file; do
            sed -i "s|@HOME@|$HOME|g" "$file"
        done < <(rg -l '@HOME@' "$path" || true)
    else
        sed -i "s|@HOME@|$HOME|g" "$path"
    fi
done

chmod u+x "$HOME/.local/bin"/windows-* "$HOME/.local/bin/hypr-profile-switch"

cp -- "$HOME/.config/hypr/profiles/windows11/colors.conf" "$HOME/.config/hypr/colors.conf"
cp -- "$HOME/.config/hypr/profiles/windows11/config/"*.conf "$HOME/.config/hypr/config/"

printf 'Installed. Backup: %s\n' "$backup"
printf 'Edit %s for your weather location.\n' "$HOME/.config/windows11/location.json"

if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    hyprctl reload
    "$HOME/.local/bin/windows-shell" restart
fi
