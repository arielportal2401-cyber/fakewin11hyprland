# Fake Windows 11 for Hyprland

Windows 11 looks, Linux behavior underneath. This rice uses a floating
Hyprland layout, a Windows-style Waybar taskbar, Quickshell menus, working app
pinning, quick settings, screenshots, snapping, weather, wallpaper switching
and a matching Fastfetch setup.

> [!IMPORTANT]
> The installer keeps a dated recovery copy before replacing anything. If an
> existing Hyprland config is detected, you choose whether it also remains as
> a switchable ORIGINAL profile.

---

# BEGINNER QUICK INSTALL

Copy these three commands into a terminal:

```bash
git clone https://github.com/arielportal2401-cyber/fakewin11hyprland.git
cd fakewin11hyprland
./install.sh
```

That is the normal installation. The script explains what it will do, asks how
to handle any existing Hyprland config, and handles the rest automatically.

> [!WARNING]
> Do **not** run `sudo ./install.sh`. Run it as the normal desktop user. The
> installer requests sudo itself only when the package manager needs it. This
> keeps the configuration and lock screen attached to the correct user account.

For a completely non-interactive install:

```bash
./install.sh --yes
```

`--yes` uses clean replacement mode. It assumes no old Hyprland profile needs
to remain installed, while still moving any detected config into the dated
recovery directory.

## What the installer does automatically

1. Detects installed programs.
2. Installs only missing dependencies.
3. Verifies that every required command is actually available.
4. Offers clean replacement or a preserved, switchable **ORIGINAL** profile.
5. Creates a timestamped recovery copy in either mode.
6. Installs the **WINDOWS** profile separately.
7. Replaces template paths with the current user's real home directory.
8. Checks the installed files and reloads Hyprland.

Supported package managers: Pacman, APT, DNF, Zypper, XBPS, APK and Nix. If a
native repository is missing a current package and Nix is already installed,
the installer tries Nix only for the unresolved commands.

---

# THE TWO PROFILES — KEPT SEPARATE

```text
~/.config/hypr/profiles/
├── original/     your previous Hyprland config and keybindings
└── windows11/    this rice and its Windows-style keybindings
```

Switch the whole desktop, including its keybindings:

```bash
hypr-profile-switch windows11
hypr-profile-switch original
```

The original option appears only when the installer finds an existing modular
Hyprland config. Either way, a complete timestamped backup is saved under:

```text
~/.local/state/windows11-rice/backups/
```

The latest backup path is also recorded in:

```text
~/.local/state/windows11-rice/latest-backup
```

---

# PASSWORD AND LOCK SCREEN

`Win + L` uses Hyprlock and PAM. Enter the same password used to log into the
current Linux account.

- There is no default password from this repository.
- The installer never reads or stores a password.
- No password, token, Wi-Fi secret or API key is committed to GitHub.

---

# FIRST THINGS TO TRY

| Shortcut | Action |
| --- | --- |
| `Win` | Open Start |
| `Win + E` | Open File Explorer |
| `Win + Tab` | Open the window switcher |
| `Win + Left/Right` | Snap the active window |
| `Win + F` | Toggle fullscreen and taskbar visibility |
| `Win + Space` | Cycle floating, corner, master, stack and scrolling layouts |
| `Win + mouse wheel` | Cycle quickly through workspaces |
| `Win + Shift + S` | Select a screenshot region |
| `Win + L` | Lock with the normal account password |
| `Alt + F4` | Close the active window |

Fullscreen taskbar visibility follows the focused workspace. Moving away from
a fullscreen app shows the taskbar; returning to it hides the taskbar again.
`Win + F` does nothing when no application window is focused.

New application windows automatically join whichever `Win + Space` tiling mode
is active. In Windows floating mode, they continue to open as normal floating
windows.

The taskbar keeps pinned apps centered and adds ten compact workspace tabs beside
the weather widget. Click a number to switch workspaces; the active one gets a
subtle Fluent-blue indicator.

---

# FEATURES AND DEPENDENCIES

The automatic installer provides:

- Hyprland, Hyprlock, Quickshell, Waybar and Rofi
- PipeWire audio tools and Hyprland desktop portals for screen sharing
- awww wallpaper handling
- grim, slurp, Satty and wl-clipboard screenshots
- iwd Wi-Fi and BlueZ Bluetooth command-line backends
- Thunar, Kitty, Fastfetch, Yad, jq and Python
- notification, brightness, media, clipboard and icon helpers
- repaired XDG Downloads, Pictures and Videos defaults for sandboxed file pickers
- a translucent Kitty theme, Starship prompt, eza, bat, zoxide, btop, Cava,
  pipes-rs and Chafa
- native animated calendar, notifications, power and system-control flyouts

The Wi-Fi controls currently use iwd rather than NetworkManager. On a system
where NetworkManager owns Wi-Fi, install iwd and switch backends deliberately;
the installer will not disconnect an active network behind your back.

Weather uses Open-Meteo without an API key. Change the example location here:

```text
~/.config/windows11/location.json
```

---

# CUSTOMIZATION — ADVANCED

You do not need this section to install the rice.

| What to change | Repository path |
| --- | --- |
| Default pinned apps | `local/bin/windows-taskbar-pins` |
| Start menu apps | `config/quickshell/windows11/shell.qml` |
| Taskbar layout | `config/waybar/windows11/config.jsonc` |
| Taskbar appearance | `config/waybar/windows11/style.css` |
| Keybindings | `config/hypr/profiles/windows11/config/keybindings.conf` |
| Monitors | `config/hypr/profiles/windows11/config/monitors.conf` |
| Keyboard layout | `config/hypr/profiles/windows11/config/settings.conf` |

## Known rough edges

- The notification button is a small panel, not complete notification history.
- Pinned app matching depends on the application's Wayland class.
- The default app list contains personal choices; remove anything not installed.
- Hyprland moves quickly. Arch and NixOS generally provide the least painful
  package experience.

---

# CREDITS

The modular Hyprland base was derived from ilyamiro's dotfiles. Fluent-style
icons and Windows visual references belong to their respective creators and are
not covered by the MIT license for the scripts and configuration.

Windows is a Microsoft trademark. This project is unofficial and is not
affiliated with Microsoft.
