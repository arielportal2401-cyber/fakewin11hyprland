#!/usr/bin/env bash

set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
stamp="$(date +%Y%m%d-%H%M%S)"
backup="$HOME/.local/state/windows11-rice/backups/$stamp"

assume_yes=false
for argument in "$@"; do
    case "$argument" in
        --yes|-y) assume_yes=true ;;
        --help|-h)
            printf 'usage: %s [--yes]\n\n' "$0"
            printf '  --yes, -y  Install automatically in clean/replace mode.\n'
            exit 0
            ;;
        *) printf 'Unknown option: %s\nTry %s --help\n' "$argument" "$0" >&2; exit 2 ;;
    esac
done

if [[ -t 1 ]]; then
    blue=$'\033[38;2;96;205;255m'
    green=$'\033[38;2;72;199;116m'
    yellow=$'\033[38;2;255;193;7m'
    red=$'\033[38;2;255;99;99m'
    bold=$'\033[1m'
    reset=$'\033[0m'
else
    blue="" green="" yellow="" red="" bold="" reset=""
fi

rule() {
    printf '%s\n' '================================================================'
}

phase() {
    printf '\n%s%s[%s/5] %s%s\n' "$blue" "$bold" "$1" "$2" "$reset"
}

success() {
    printf '%s[OK]%s %s\n' "$green" "$reset" "$1"
}

warning() {
    printf '%s[WARNING]%s %s\n' "$yellow" "$reset" "$1" >&2
}

failure() {
    printf '%s[ERROR]%s %s\n' "$red" "$reset" "$1" >&2
}

if ((EUID == 0)); then
    failure 'Do not run the whole installer with sudo or as root.'
    printf 'Run ./install.sh as your normal desktop user. It asks for sudo only when a package needs it.\n' >&2
    exit 1
fi

if ! $assume_yes && [[ ! -t 0 ]]; then
    failure 'Run interactively or use ./install.sh --yes.'
    exit 1
fi

rule
printf '%s%s       FAKE WINDOWS 11 FOR HYPRLAND - AUTOMATIC INSTALLER%s\n' "$blue" "$bold" "$reset"
rule
printf '\nThis installer will:\n'
printf '  1. Check and install missing dependencies.\n'
printf '  2. Ask whether an existing Hyprland setup should be preserved.\n'
printf '  3. Install a clean WINDOWS profile without requiring an old config.\n'
printf '  4. Install the taskbar, Start menu, settings and helper scripts.\n'
printf '  5. Verify the result and reload Hyprland.\n\n'

preserve_current=false
if [[ -f "$HOME/.config/hypr/hyprland.conf" || \
      -d "$HOME/.config/hypr/config" || \
      -d "$HOME/.config/hypr/profiles" ]]; then
    printf '%sExisting Hyprland config detected.%s\n' "$yellow" "$reset"
    printf '  1. Clean install / replace it (default)\n'
    printf '  2. Preserve it as a switchable ORIGINAL profile\n'
    if ! $assume_yes; then
        read -r -p 'Choose 1 or 2 [1]: ' config_choice
        case "${config_choice:-1}" in
            1) ;;
            2) preserve_current=true ;;
            *) failure 'Please choose 1 or 2.'; exit 2 ;;
        esac
    else
        printf 'Automatic mode selected: clean install / replace.\n'
    fi
else
    success 'No existing Hyprland config detected; using a clean install.'
fi

printf '\n%sINSTALL LAYOUT%s\n' "$bold" "$reset"
if $preserve_current; then
    printf '  ORIGINAL : %s\n' "$HOME/.config/hypr/profiles/original"
fi
printf '  WINDOWS  : %s\n' "$HOME/.config/hypr/profiles/windows11"
printf '  RECOVERY : %s\n' "$backup"

if ! $assume_yes; then
    printf '\n'
    read -r -p 'Continue with the automatic installation? [Y/n] ' answer
    [[ "${answer:-y}" =~ ^[Yy]$ ]] || { printf 'Nothing was changed.\n'; exit 0; }
fi

dependencies=(
    hyprctl quickshell waybar rofi rg jq python3 yad awww grim slurp wl-copy
    hyprlock thunar kitty fastfetch iwctl bluetoothctl pavucontrol playerctl
    brightnessctl satty notify-send magick wpctl pactl swayosd-client cliphist
    xdg-desktop-portal xdg-desktop-portal-hyprland xdg-user-dir pipewire flatpak
    starship eza bat zoxide btop cava pipes-rs chafa
)

missing_commands() {
    local command
    for command in "${dependencies[@]}"; do
        dependency_present "$command" || printf '%s\n' "$command"
    done
}

dependency_present() {
    local command="$1" directory
    if command -v "$command" >/dev/null 2>&1; then
        return 0
    fi
    case "$command" in
        xdg-desktop-portal|xdg-desktop-portal-hyprland)
            for directory in \
                "$HOME/.nix-profile/libexec" \
                /run/current-system/sw/libexec \
                /usr/libexec \
                /usr/lib/xdg-desktop-portal \
                /usr/lib; do
                [[ -x "$directory/$command" ]] && return 0
            done
            ;;
    esac
    return 1
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
        *:swayosd-client) printf 'swayosd\n' ;;
        *:xdg-user-dir) printf 'xdg-user-dirs\n' ;;
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
        swayosd-client) printf 'swayosd\n' ;;
        xdg-user-dir) printf 'xdg-user-dirs\n' ;;
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

phase 1 'Checking dependencies'
mapfile -t missing < <(missing_commands)
if ((${#missing[@]})); then
    warning 'Some required programs are missing:'
    printf '  %s\n' "${missing[@]}"

    manager="$(detect_package_manager || true)"
    if [[ -z "$manager" ]]; then
        failure 'No supported package manager was found.'
        exit 1
    fi
    printf 'Package manager: %s\n' "$manager"
    printf 'Installing only the missing packages now.\n'

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
            warning "$manager could not install $package."
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
        failure 'These commands are still missing after installation:'
        printf '  %s\n' "${missing[@]}" >&2
        printf 'Your distribution does not provide every required package.\n' >&2
        exit 1
    fi
fi
success 'Every dependency is available.'

phase 2 'Backing up the current desktop'
mkdir -p \
    "$backup/config/quickshell" \
    "$backup/config/waybar" \
    "$backup/config/kitty" \
    "$backup/config/cava" \
    "$backup/config/btop" \
    "$backup/local/share/applications" \
    "$backup/local/share/icons" \
    "$HOME/.config" \
    "$HOME/.local/bin" \
    "$HOME/.local/share/windows11/wallpapers"

if [[ -e "$HOME/.config/hypr" ]]; then
    if $preserve_current; then
        cp -a -- "$HOME/.config/hypr" "$backup/config/"
    else
        mv -- "$HOME/.config/hypr" "$backup/config/hypr"
        success 'Existing Hyprland config moved into the recovery backup.'
    fi
fi
[[ -e "$HOME/.config/quickshell/windows11" ]] && \
    cp -a -- "$HOME/.config/quickshell/windows11" "$backup/config/quickshell/"
[[ -e "$HOME/.config/waybar/windows11" ]] && \
    cp -a -- "$HOME/.config/waybar/windows11" "$backup/config/waybar/"
[[ -e "$HOME/.config/fastfetch" ]] && cp -a -- "$HOME/.config/fastfetch" "$backup/config/"
[[ -e "$HOME/.config/kitty" ]] && cp -a -- "$HOME/.config/kitty" "$backup/config/"
[[ -e "$HOME/.config/starship.toml" ]] && cp -- "$HOME/.config/starship.toml" "$backup/config/"
[[ -e "$HOME/.config/cava" ]] && cp -a -- "$HOME/.config/cava" "$backup/config/"
[[ -e "$HOME/.config/btop" ]] && cp -a -- "$HOME/.config/btop" "$backup/config/"
[[ -e "$HOME/.bashrc" ]] && cp -- "$HOME/.bashrc" "$backup/bashrc"
[[ -e "$HOME/.local/share/applications/hypr-config-switcher.desktop" ]] && \
    cp -- "$HOME/.local/share/applications/hypr-config-switcher.desktop" "$backup/local/share/applications/"
[[ -e "$HOME/.local/share/applications/windows-settings.desktop" ]] && \
    cp -- "$HOME/.local/share/applications/windows-settings.desktop" "$backup/local/share/applications/"
[[ -e "$HOME/.local/share/icons/hicolor/256x256/apps/desktop-style-switcher.png" ]] && \
    cp -- "$HOME/.local/share/icons/hicolor/256x256/apps/desktop-style-switcher.png" "$backup/local/share/icons/"
mkdir -p "$HOME/.local/state/windows11-rice"
printf '%s\n' "$backup" > "$HOME/.local/state/windows11-rice/latest-backup"
success "Backup saved to $backup"

# The switcher only creates ORIGINAL when the user explicitly preserves it.
phase 3 'Preparing cleanly separated profiles'
original="$HOME/.config/hypr/profiles/original"
if $preserve_current; then
    if [[ ! -d "$original" && -d "$HOME/.config/hypr/config" ]]; then
        mkdir -p "$original"
        [[ -f "$HOME/.config/hypr/colors.conf" ]] && cp -- "$HOME/.config/hypr/colors.conf" "$original/colors.conf"
        cp -a -- "$HOME/.config/hypr/config" "$original/config"
    fi
    if [[ -d "$original/config" ]]; then
        success "ORIGINAL profile: $original"
    else
        warning 'The old config was backed up, but it was not modular enough to become an ORIGINAL profile.'
    fi
    # ORIGINAL is now safely stored under profiles/. Remove the active modular
    # files so old keybindings cannot leak into the Windows profile.
    if [[ -d "$HOME/.config/hypr/config" ]]; then
        mkdir -p "$backup/replaced"
        mv -- "$HOME/.config/hypr/config" "$backup/replaced/active-hypr-config"
    fi
else
    success 'Clean mode selected; no old files will be mixed into WINDOWS.'
fi
printf 'WINDOWS profile destination: %s\n' "$HOME/.config/hypr/profiles/windows11"

phase 4 'Installing the Windows desktop'
mkdir -p \
    "$HOME/.config/hypr/config" \
    "$HOME/.config/hypr/profiles" \
    "$HOME/.config/fastfetch" \
    "$HOME/.config/kitty" \
    "$HOME/.config/cava" \
    "$HOME/.config/btop" \
    "$HOME/.config/quickshell" \
    "$HOME/.config/waybar" \
    "$HOME/.config/windows11" \
    "$HOME/.local/share/applications" \
    "$HOME/.local/share/icons/hicolor/256x256/apps"

# A missing user-dirs file makes some sandboxed apps treat the whole home
# directory as Downloads. Keep existing custom locations, but repair unset
# defaults before file-picker portals and Flatpak apps start.
ensure_user_directory() {
    local name="$1" fallback="$2" current
    current="$(xdg-user-dir "$name" 2>/dev/null || true)"
    if [[ -z "$current" || "$current" == "$HOME" ]]; then
        mkdir -p "$fallback"
        xdg-user-dirs-update --set "$name" "$fallback"
    fi
}
ensure_user_directory DOWNLOAD "$HOME/Downloads"
ensure_user_directory PICTURES "$HOME/Pictures"
ensure_user_directory VIDEOS "$HOME/Videos"

# Install clean profile directories so files removed by newer releases do not
# survive from an older installation. The complete previous copy is above.
mkdir -p "$backup/replaced"
for installed_path in \
    "$HOME/.config/hypr/profiles/windows11" \
    "$HOME/.config/quickshell/windows11" \
    "$HOME/.config/waybar/windows11"; do
    if [[ -e "$installed_path" ]]; then
        name="$(printf '%s' "$installed_path" | sed 's#^/##; s#/#__#g')"
        mv -- "$installed_path" "$backup/replaced/$name"
    fi
done

cp -a -- "$repo/config/hypr/profiles/windows11" "$HOME/.config/hypr/profiles/"
cp -a -- "$repo/config/quickshell/windows11" "$HOME/.config/quickshell/"
cp -a -- "$repo/config/waybar/windows11" "$HOME/.config/waybar/"
cp -- "$repo/config/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
cp -- "$repo/config/kitty/"*.conf "$HOME/.config/kitty/"
cp -- "$repo/config/kitty/"*.py "$HOME/.config/kitty/"
cp -- "$repo/config/starship.toml" "$HOME/.config/starship.toml"
cp -- "$repo/config/cava/config" "$HOME/.config/cava/config"
cp -- "$repo/config/btop/btop.conf" "$HOME/.config/btop/btop.conf"
cp -- "$repo/config/hypr/hyprland.conf" "$HOME/.config/hypr/hyprland.conf"
cp -- "$repo/config/hypr/hyprlock-windows.conf" "$HOME/.config/hypr/hyprlock-windows.conf"
cp -- "$repo/local/bin/"* "$HOME/.local/bin/"
cp -- "$repo/share/wallpapers/"* "$HOME/.local/share/windows11/wallpapers/"
cp -- "$repo/local/share/applications/"*.desktop "$HOME/.local/share/applications/"
cp -- "$repo/local/share/icons/hicolor/256x256/apps/"*.png \
    "$HOME/.local/share/icons/hicolor/256x256/apps/"

if [[ ! -f "$HOME/.config/windows11/location.json" ]]; then
    cp -- "$repo/config/windows11/location.json" "$HOME/.config/windows11/location.json"
fi

# Repository files use a token where QML and Waybar cannot expand $HOME.
for path in \
    "$HOME/.config/hypr/hyprlock-windows.conf" \
    "$HOME/.config/hypr/profiles/windows11" \
    "$HOME/.config/quickshell/windows11" \
    "$HOME/.config/waybar/windows11" \
    "$HOME/.local/share/applications/hypr-config-switcher.desktop" \
    "$HOME/.local/share/applications/windows-settings.desktop" \
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

chmod u+x \
    "$HOME/.local/bin"/windows-* \
    "$HOME/.local/bin/start-desktop-portals" \
    "$HOME/.local/bin/hypr-profile-switch" \
    "$HOME/.local/bin/hypr-config-switcher"

# Merge the interactive prompt and aliases once; never replace the user's
# existing Bash setup. The full pre-install .bashrc is also in the backup.
touch "$HOME/.bashrc"
if ! rg -q '^# WINDOWS11_RICE_SHELL_START$' "$HOME/.bashrc"; then
    printf '\n' >> "$HOME/.bashrc"
    sed -n '/^# WINDOWS11_RICE_SHELL_START$/,/^# WINDOWS11_RICE_SHELL_END$/p' \
        "$repo/config/shell/windows11.bashrc" >> "$HOME/.bashrc"
fi

command -v update-desktop-database >/dev/null 2>&1 && \
    update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true

cp -- "$HOME/.config/hypr/profiles/windows11/colors.conf" "$HOME/.config/hypr/colors.conf"
cp -- "$HOME/.config/hypr/profiles/windows11/config/"*.conf "$HOME/.config/hypr/config/"
mkdir -p "$HOME/.local/state/hypr-profile-switcher"
printf 'windows11\n' > "$HOME/.local/state/hypr-profile-switcher/current"
success 'Windows profile files installed.'

phase 5 'Verifying and starting the desktop'
for required_file in \
    "$HOME/.config/hypr/config/keybindings.conf" \
    "$HOME/.config/quickshell/windows11/shell.qml" \
    "$HOME/.config/waybar/windows11/config.jsonc" \
    "$HOME/.config/kitty/kitty.conf" \
    "$HOME/.config/kitty/resize_font.py" \
    "$HOME/.config/starship.toml" \
    "$HOME/.local/bin/windows-shell" \
    "$HOME/.local/bin/windows-command-exec" \
    "$HOME/.local/bin/windows-personalization" \
    "$HOME/.local/bin/windows-flatpak" \
    "$HOME/.local/bin/windows-workspace-cycle" \
    "$HOME/.local/bin/windows-layout-watch" \
    "$HOME/.local/bin/windows-taskbar-watch"; do
    if [[ ! -e "$required_file" ]]; then
        failure "Installation verification failed: $required_file is missing."
        exit 1
    fi
done

if rg -l '@HOME@' \
    "$HOME/.config/hypr/profiles/windows11" \
    "$HOME/.config/quickshell/windows11" \
    "$HOME/.config/waybar/windows11" >/dev/null 2>&1; then
    failure 'Installation verification found an unresolved home-directory token.'
    exit 1
fi
success 'Installed files passed verification.'

if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    hyprctl reload
    "$HOME/.local/bin/windows-layout-cycle" reset
    "$HOME/.local/bin/windows-shell" restart
    success 'Hyprland reloaded and the Windows shell started.'
else
    warning 'Hyprland is not running. Start a Hyprland session to load the desktop.'
fi

printf '\n'
rule
printf '%s%s                 INSTALLATION COMPLETE%s\n' "$green" "$bold" "$reset"
rule
printf '\nWINDOWS profile : %s\n' "$HOME/.config/hypr/profiles/windows11"
if [[ -d "$original/config" ]]; then
    printf 'ORIGINAL profile: %s\n' "$original"
    printf '\nSwitch later with:\n'
    printf '  hypr-profile-switch windows11\n'
    printf '  hypr-profile-switch original\n'
fi
printf '\nYour backup     : %s\n' "$backup"
printf 'Weather location: %s\n' "$HOME/.config/windows11/location.json"
printf 'Lock password   : your normal Linux login password (nothing is stored)\n'
printf '\nPress Win for Start, Win+F for fullscreen, and Win+Shift+S for screenshots.\n'
