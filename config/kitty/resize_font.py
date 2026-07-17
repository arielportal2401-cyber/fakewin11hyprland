"""Scale Kitty's font with the size of its Hyprland tile."""

from typing import Any

from kitty.boss import Boss
from kitty.fast_data_types import os_window_font_size
from kitty.window import Window


BASE_FONT_SIZE = 12.5
BASE_WIDTH = 1014
BASE_HEIGHT = 640
MIN_FONT_SIZE = 8.0
MAX_FONT_SIZE = 15.0
last_size: dict[int, float] = {}


def on_resize(boss: Boss, window: Window, data: dict[str, Any]) -> None:
    geometry = data["new_geometry"]
    width = max(1, geometry.right - geometry.left)
    height = max(1, geometry.bottom - geometry.top)
    scale = min(width / BASE_WIDTH, height / BASE_HEIGHT)
    target = max(MIN_FONT_SIZE, min(MAX_FONT_SIZE, BASE_FONT_SIZE * scale))
    target = round(target * 2) / 2

    os_window_id = window.os_window_id
    if last_size.get(os_window_id) == target:
        return

    current = os_window_font_size(os_window_id)
    if current and abs(current - target) >= 0.25:
        last_size[os_window_id] = target
        boss._change_font_size({os_window_id: target})
