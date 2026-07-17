# Windows 11, except it is Hyprland

I wanted Hyprland to feel close enough to Windows 11 that I could complain
about Windows while still using Linux. This is the result.

It is a floating Hyprland desktop with a Windows-style Waybar taskbar, Start
menu, quick settings, app pinning, Wi-Fi/Bluetooth controls, weather, wallpaper
switching, snapping, a matching Fastfetch config, and a small profile switcher
for escaping back to your old rice when something inevitably breaks.

This is a personal rice built while learning. It is not a desktop environment,
and a few menus are deliberately tiny instead of trying to clone every page of
Windows Settings.

## Install

Read the script first. It copies files into `~/.config` and `~/.local/bin`, but
backs up the existing Hyprland, Waybar, and Windows Quickshell files before it
does that.

```bash
git clone https://github.com/arielportal2401-cyber/fakewin11hyprland.git windows11-hyprland-dotfiles
cd windows11-hyprland-dotfiles
chmod +x install.sh
./install.sh
```

Backups go under `~/.local/state/windows11-rice/backups/`.

## Dependencies

The installer checks commands instead of guessing which Linux distribution you
use. Install these through your package manager first:

- Hyprland, Quickshell, Waybar and Hyprlock
- Rofi, Yad, jq and Python 3
- awww, grim, slurp and wl-clipboard
- Thunar and Kitty
- iwd/`iwctl` for Wi-Fi and BlueZ/`bluetoothctl` for Bluetooth
- Fastfetch for the matching terminal system summary
- `pavucontrol`, `playerctl`, `brightnessctl`, `satty` and `notify-send` for the
  optional controls and screenshot editing

Weather uses Open-Meteo without an API key. Change
`~/.config/windows11/location.json` after installation.

## Shortcuts

| Shortcut | Action |
| --- | --- |
| `Win` | Start menu |
| `Win + E` | File Explorer |
| `Win + Tab` | Window switcher |
| `Win + Left/Right` | Snap window |
| `Win + F` | Toggle fullscreen and taskbar |
| `Win + Shift + S` | Select a screenshot region |
| `Win + L` | Lock |

The Windows shortcuts live only in the Windows profile. Run
`hypr-profile-switch original` or `hypr-profile-switch windows11` to switch the
whole config, including keybindings.

## Things you will probably edit

- Default pinned apps: `local/bin/windows-taskbar-pins`
- Start menu apps: `config/quickshell/windows11/shell.qml`
- Taskbar: `config/waybar/windows11/`
- Keyboard layout and monitors: `config/hypr/profiles/windows11/config/`

## Known rough edges

- Network controls currently expect iwd rather than NetworkManager.
- The notification button is a minimal panel, not full notification history.
- Pinned app matching depends on the app's Wayland class. Weird launchers may
  need their match expression adjusted.
- The default app list contains software I use; remove whatever you do not.

## Credits

The modular Hyprland base was derived from ilyamiro's dotfiles. Fluent-style
icons and Windows visual references belong to their respective creators and are
not covered by the MIT license for the scripts/configuration.

Windows is a Microsoft trademark. This project is unofficial and is not
affiliated with Microsoft.
