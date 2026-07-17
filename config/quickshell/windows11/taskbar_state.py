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

print(json.dumps({
    "clients": classes,
    "active": str(active.get("class") or active.get("initialClass") or "").casefold(),
}))
