#!/usr/bin/env python3
"""Add the opt-in SlozOS Performance Mode switch to the SlozOS Portal."""
import yaml

PATH = "/usr/share/yafti/yafti.yml"
PAUSE = '; status=$?; echo; echo "Press Enter to close..."; read -r _; exit $status'

cfg = yaml.safe_load(open(PATH))
action = {
    "id": "slozos-performance-mode",
    "title": "SlozOS Performance Mode",
    "description": "More FPS in games and Minecraft by turning off CPU security mitigations "
                   "(Spectre/Meltdown). Faster on these older Surfaces, but less protected "
                   "against malicious code. Takes effect after a reboot.",
    "default": False,
    "status_script": "slozos-performance-mode status",
    "options": [
        {"id": "on", "label": "Turn Performance Mode on", "script": "slozos-performance-mode on" + PAUSE},
        {"id": "off", "label": "Turn Performance Mode off", "script": "slozos-performance-mode off" + PAUSE},
    ],
}
for screen in cfg.get("screens", []):
    if screen.get("title") == "Manage SlozOS":
        screen.setdefault("actions", []).insert(1, action)
yaml.safe_dump(cfg, open(PATH, "w"), sort_keys=False, allow_unicode=True, width=1000)
