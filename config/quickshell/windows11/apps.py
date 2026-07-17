#!/usr/bin/env python3

import configparser
import glob
import json
import os
import re
import shlex


def application_directories():
    home = os.path.expanduser("~")
    return [
        f"{home}/.local/share/applications",
        f"{home}/.local/share/flatpak/exports/share/applications",
        f"{home}/.nix-profile/share/applications",
        "/var/lib/flatpak/exports/share/applications",
        "/usr/local/share/applications",
        "/usr/share/applications",
    ]


apps = {}

# Helper utilities and duplicate frontends that should not be presented as
# normal Start-menu applications. They remain installed and usable directly.
hidden_names = {
    "advanced network configuration",
    "bluetooth adapters",
    "bluetooth manager",
    "bulk rename",
    "files",
    "foot",
    "foot client",
    "foot server",
    "gvim",
    "icon browser",
    "input-remapper-autoload",
    "microsoft store",
    "microsoft edge",
    "rofi",
    "rofi theme selector",
    "thunar preferences",
    "vim",
    "yad settings",
}

icon_aliases = {
    # OpenTabletDriver's desktop file references an icon that is not shipped
    # in the active icon theme. Use a related installed device icon instead.
    "otd": "input-remapper",
}

for directory in application_directories():
    for filename in glob.glob(os.path.join(directory, "**", "*.desktop"), recursive=True):
        parser = configparser.ConfigParser(interpolation=None, strict=False)
        try:
            parser.read(filename, encoding="utf-8")
            entry = parser["Desktop Entry"]

            if entry.getboolean("NoDisplay", fallback=False):
                continue
            if entry.get("Type", "Application") != "Application":
                continue

            name = entry.get("Name", "").strip()
            command = entry.get("Exec", "").strip()
            icon = entry.get("Icon", "application-x-executable").strip()
            icon = icon_aliases.get(icon, icon)

            if not name or not command:
                continue
            if name.casefold() in hidden_names:
                continue

            # Desktop files use placeholders such as %U and %f. They are not
            # meaningful when launching a result without a selected file.
            command = " ".join(
                part for part in command.split()
                if not part.startswith("%") and part not in {"@@", "@@u"}
            )

            startup_class = entry.get("StartupWMClass", "").strip()
            if startup_class:
                match = "^(" + re.escape(startup_class) + ")$"
            else:
                words = shlex.split(command)
                candidates = [os.path.basename(words[0])] if words else []
                if len(words) >= 3 and candidates and candidates[0] == "flatpak" and words[1] == "run":
                    candidates.extend([words[2], words[2].split(".")[-1]])
                match = "^(" + "|".join(re.escape(item) for item in candidates) + ")$" if candidates else ""

            apps.setdefault(name.casefold(), {
                "name": name,
                "exec": command,
                "icon": icon,
                "match": match,
            })
        except (OSError, KeyError, configparser.Error):
            continue

print(json.dumps(sorted(apps.values(), key=lambda app: app["name"].casefold())))
