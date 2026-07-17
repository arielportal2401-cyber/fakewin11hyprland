#!/usr/bin/env python3

import json
import re
import subprocess


def run(*args, timeout=4):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=timeout).stdout
    except (OSError, subprocess.SubprocessError):
        return ""


controller = run("bluetoothctl", "show")
powered = bool(re.search(r"Powered:\s+yes", controller, re.I))
devices = []
for line in run("bluetoothctl", "devices").splitlines():
    match = re.match(r"Device\s+([0-9A-F:]{17})\s+(.+)", line, re.I)
    if not match:
        continue
    address, name = match.groups()
    info = run("bluetoothctl", "info", address)
    devices.append({
        "address": address,
        "name": name,
        "paired": bool(re.search(r"Paired:\s+yes", info, re.I)),
        "connected": bool(re.search(r"Connected:\s+yes", info, re.I)),
        "icon": (re.search(r"Icon:\s+(.+)", info, re.I) or [None, "bluetooth"])[1].strip(),
    })

devices.sort(key=lambda item: (not item["connected"], not item["paired"], item["name"].casefold()))
print(json.dumps({"powered": powered, "devices": devices}))
