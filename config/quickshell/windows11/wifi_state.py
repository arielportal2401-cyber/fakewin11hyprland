#!/usr/bin/env python3

import glob
import json
import os
import re
import subprocess

ANSI = re.compile(r"\x1b\[[0-9;]*m")


def run(*command, timeout=6):
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=timeout)
        return ANSI.sub("", result.stdout + result.stderr)
    except (OSError, subprocess.SubprocessError):
        return ""


interfaces = [os.path.basename(path) for path in glob.glob("/sys/class/net/*")
              if os.path.isdir(os.path.join(path, "wireless"))]
interface = interfaces[0] if interfaces else ""
networks = []
connected = ""
powered = False

if interface:
    device = run("iwctl", "device", interface, "show")
    powered = bool(re.search(r"Powered\s+on", device, re.I))
    station = run("iwctl", "station", interface, "show")
    match = re.search(r"Connected network\s+(.+?)\s*$", station, re.I | re.M)
    if match:
        connected = match.group(1).strip()

    listing = run("iwctl", "station", interface, "get-networks", "rssi-bars")
    for line in listing.splitlines():
        match = re.match(r"^\s*(>?)\s*(.*?)\s{2,}(open|psk|8021x|owe|sae)\s+(\*+)\s*$", line, re.I)
        if not match:
            continue
        name = match.group(2).strip()
        if name and not any(item["name"] == name for item in networks):
            networks.append({
                "name": name,
                "security": match.group(3).lower(),
                "signal": len(match.group(4)),
                "connected": match.group(1) == ">" or name == connected,
            })

print(json.dumps({
    "interface": interface,
    "powered": powered,
    "connected": connected,
    "networks": networks,
}))
