#!/usr/bin/env python3

import json
import subprocess


def hyprland_json(command):
    try:
        result = subprocess.run(
            ["hyprctl", command, "-j"],
            check=True,
            capture_output=True,
            text=True,
        )
        return json.loads(result.stdout)
    except (OSError, subprocess.SubprocessError, json.JSONDecodeError):
        return [] if command == "clients" else {}


clients = hyprland_json("clients")
active = hyprland_json("activewindow")

classes = sorted({
    str(client.get("class") or client.get("initialClass") or "").casefold()
    for client in clients
    if client.get("class") or client.get("initialClass")
})

minimized = []
for client in clients:
    workspace = client.get("workspace") or {}
    if workspace.get("name") != "special:minimized" or not client.get("mapped", False):
        continue
    class_name = str(client.get("class") or client.get("initialClass") or "application-x-executable")
    lowered = class_name.casefold()
    if "discord" in lowered:
        icon = "discord"
    elif "spotify" in lowered:
        icon = "spotify-client"
    elif "zen" in lowered:
        icon = "zen-browser"
    else:
        icon = class_name
    minimized.append({
        "address": str(client.get("address") or ""),
        "name": str(client.get("title") or class_name),
        "class": class_name,
        "icon": icon,
    })

print(json.dumps({
    "clients": classes,
    "active": str(active.get("class") or active.get("initialClass") or "").casefold(),
    "address": str(active.get("address") or ""),
    "minimized": minimized,
}))
