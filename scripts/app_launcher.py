#!/usr/bin/python3
import configparser
import glob
import json
import os
import shlex
import subprocess
import sys

DESKTOP_DIRS = [
    "/usr/share/applications",
    os.path.expanduser("~/.local/share/applications"),
    "/var/lib/flatpak/exports/share/applications",
    os.path.expanduser("~/.local/share/flatpak/exports/share/applications"),
]


def first_value(parser, section, key, fallback=""):
    try:
        return parser.get(section, key, fallback=fallback, raw=True)
    except Exception:
        return fallback


def desktop_files():
    found = {}
    for directory in DESKTOP_DIRS:
        if not os.path.isdir(directory):
            continue
        for path in sorted(glob.glob(os.path.join(directory, "*.desktop"))):
            found.setdefault(os.path.basename(path), path)
    return found.values()


def expand_exec(value):
    value = shlex.split(value)
    cleaned = []
    for token in value:
        if token.startswith("%"):
            continue
        cleaned.append(token.replace("%%", "%") if "%%" in token else token)
    return cleaned


def list_apps():
    apps = []
    for path in desktop_files():
        parser = configparser.ConfigParser(interpolation=None)
        parser.optionxform = str
        try:
            parser.read(path, encoding="utf-8")
        except Exception:
            continue
        if not parser.has_section("Desktop Entry"):
            continue

        if first_value(parser, "Desktop Entry", "Type") != "Application":
            continue
        if first_value(parser, "Desktop Entry", "NoDisplay").lower() == "true":
            continue
        if first_value(parser, "Desktop Entry", "Hidden").lower() == "true":
            continue

        name = first_value(parser, "Desktop Entry", "Name")
        exec_value = first_value(parser, "Desktop Entry", "Exec")
        if not name or not exec_value:
            continue

        categories = first_value(parser, "Desktop Entry", "Categories")
        apps.append({
            "id": os.path.splitext(os.path.basename(path))[0],
            "name": name,
            "comment": first_value(parser, "Desktop Entry", "Comment"),
            "icon": first_value(parser, "Desktop Entry", "Icon", "application-x-executable"),
            "exec": exec_value,
            "categories": [item for item in categories.split(";") if item],
        })

    apps.sort(key=lambda app: app["name"].casefold())
    return apps


def launch(exec_value):
    argv = expand_exec(exec_value)
    if not argv:
        return {"ok": False, "error": "Empty Exec value"}
    try:
        subprocess.Popen(argv, cwd=os.path.expanduser("~"), start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return {"ok": True}
    except Exception as exc:
        return {"ok": False, "error": str(exc)}


def main():
    if len(sys.argv) >= 2 and sys.argv[1] == "list":
        print(json.dumps({"ok": True, "items": list_apps()}, ensure_ascii=False))
        return
    if len(sys.argv) >= 4 and sys.argv[1] == "launch" and sys.argv[2] == "--exec":
        print(json.dumps(launch(sys.argv[3]), ensure_ascii=False))
        return
    print(json.dumps({"ok": False, "error": "Usage: app_launcher.py list | launch --exec <command>"}))


if __name__ == "__main__":
    main()
