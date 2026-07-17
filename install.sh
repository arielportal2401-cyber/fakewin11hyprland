#!/usr/bin/env bash

set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
stamp="$(date +%Y%m%d-%H%M%S)"
backup="$HOME/.local/state/windows11-rice/backups/$stamp"

required=(hyprctl quickshell waybar rofi rg jq python3 yad awww grim slurp wl-copy hyprlock thunar kitty)
missing=()
for command in "${required[@]}"; do
    command -v "$command" >/dev/null 2>&1 || missing+=("$command")
done

if ((${#missing[@]})); then
    printf 'Missing required commands:\n  %s\n' "${missing[*]}" >&2
    printf 'Install them with your distro package manager, then run this again.\n' >&2
    exit 1
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
