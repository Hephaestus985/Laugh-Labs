#!/usr/bin/env python3
"""Which tests does this build need? Prints test-runner arguments.

Compares the working tree with the last release tag (arcade-*). If only game
folders changed, only those games are tested (plus the launcher and a few
other games picked by rotation, as a spot check). Any change to shared code,
the launcher, settings or the tests runs everything. FULL=1 forces everything.
"""
import json, os, subprocess, sys

ARCADE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
ROOT = os.path.dirname(ARCADE)


def git(*a):
    return subprocess.run(["git", "-C", ROOT] + list(a), capture_output=True, text=True).stdout


def main():
    if os.environ.get("FULL") == "1":
        print("")
        return
    tags = [t for t in git("tag", "--list", "arcade-*", "--sort=-v:refname").split() if t]
    if not tags:
        print("")
        return
    changed = set(git("diff", "--name-only", tags[0], "--", "arcade").split())
    changed |= set(git("ls-files", "--others", "--exclude-standard", "--", "arcade").split())
    games = set()
    # files that never affect what the app does
    harmless = ("arcade/tools/tests/last_report.txt", "arcade/tools/tests/last_pack_report.txt", "arcade/packs.json", "arcade/catalog.json", "arcade/export_presets.cfg", "arcade/project.godot")
    for f in changed:
        parts = f.split("/")
        if len(parts) >= 3 and parts[1] in ("games", "external"):
            games.add(parts[2])
        elif f.endswith(".md") or f in harmless:
            continue
        else:
            print("")  # shared code changed: test everything
            return
    if f_proj_changed(tags[0]):
        print("")
        return
    catalog = json.load(open(os.path.join(ARCADE, "catalog.json")))
    all_ids = [g["id"] for g in catalog["lab"] + catalog["external"]]
    # a rotating spot check of 3 other games, different every release
    others = [i for i in all_ids if i not in games]
    if others:
        start = (len(tags) * 3) % len(others)
        games |= set((others + others)[start:start + 3])
    print("menu only=" + ",".join(sorted(games)))


def f_proj_changed(tag):
    """project.godot changes other than the version number count as shared changes."""
    diff = git("diff", "-U0", tag, "--", "arcade/project.godot")
    for line in diff.splitlines():
        if line.startswith(("+", "-")) and not line.startswith(("+++", "---")) and "config/version" not in line:
            return True
    return False


if __name__ == "__main__":
    main()
