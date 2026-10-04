#!/usr/bin/env python3
"""Merge KDE-style INI files: ini-merge.py TARGET OVERLAY [OVERLAY...]

Every key from each OVERLAY is written into TARGET (created if missing),
overwriting keys that already exist and keeping everything else. Used so
SlozOS settings layer on top of whatever Bazzite already ships in /etc/skel
or /usr/lib instead of clobbering it.
"""
import configparser
import os
import sys


def load(path):
    cp = configparser.RawConfigParser(
        delimiters=("=",), strict=False, interpolation=None,
        comment_prefixes=("#", ";"), empty_lines_in_values=False,
    )
    cp.optionxform = str  # KDE keys are case-sensitive
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            cp.read_file(f, source=path)
    return cp


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    target = sys.argv[1]
    merged = load(target)
    for overlay in sys.argv[2:]:
        src = load(overlay)
        for section in src.sections():
            if not merged.has_section(section):
                merged.add_section(section)
            for key, value in src.items(section):
                merged.set(section, key, value)
    os.makedirs(os.path.dirname(target) or ".", exist_ok=True)
    with open(target, "w", encoding="utf-8") as f:
        merged.write(f, space_around_delimiters=False)


if __name__ == "__main__":
    main()
