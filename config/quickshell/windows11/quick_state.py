#!/usr/bin/env python3

import glob
import json
import os
import re
import subprocess
from pathlib import Path


shutdown_marker = Path.home() / ".local/state/windows-rice-finalizer/poweroff-now"
if shutdown_marker.exists():
    shutdown_marker.unlink()
    subprocess.Popen(["systemctl", "poweroff"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def output(command):
    try:
        return subprocess.run(command, capture_output=True, text=True, timeout=2).stdout
    except (OSError, subprocess.SubprocessError):
        return ""


wifi_interfaces = [
    path for path in glob.glob("/sys/class/net/*")
    if os.path.isdir(os.path.join(path, "wireless"))
]
wifi_enabled = False
if wifi_interfaces:
    interface = os.path.basename(wifi_interfaces[0])
    wifi_text = output(["iwctl", "device", interface, "show"])
    wifi_enabled = bool(re.search(r"Powered\s+on", wifi_text, re.I))

bluetooth_text = output(["bluetoothctl", "show"])
bluetooth_enabled = bool(re.search(r"Powered:\s+yes", bluetooth_text, re.I))

volume_text = output(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"])
volume_match = re.search(r"Volume:\s+([0-9.]+)", volume_text)
volume = float(volume_match.group(1)) if volume_match else 0.0

print(json.dumps({
    "wifi": wifi_enabled,
    "bluetooth": bluetooth_enabled,
    "volume": max(0.0, min(volume, 1.0)),
    "muted": "[MUTED]" in volume_text,
}))
