#!/usr/bin/env python3
"""List names inside one game's scripts (const / enum / inner class) that are also
global names in the arcade (class_name or autoload). In type positions GDScript picks
the global one, so these break when games share one project.

Usage: python3 -I tools/find_shadowing.py <game_dir>
"""
import os, re, sys

arcade = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
game = os.path.abspath(sys.argv[1])
globals_ = {}
for dp, _, fs in os.walk(arcade):
    if "/.godot" in dp:
        continue
    for f in fs:
        if f.endswith(".gd"):
            for m in re.finditer(r"^class_name\s+(\w+)", open(os.path.join(dp, f), errors="ignore").read(), re.M):
                globals_.setdefault(m.group(1), os.path.relpath(os.path.join(dp, f), arcade))
t = open(os.path.join(arcade, "project.godot")).read()
auto = t[t.index("[autoload]"):]
auto = auto[:auto.index("\n[", 1)]
for m in re.finditer(r"^(\w+)=", auto, re.M):
    globals_.setdefault(m.group(1), "autoload")
for dp, _, fs in os.walk(game):
    for f in fs:
        if not f.endswith(".gd"):
            continue
        p = os.path.join(dp, f)
        for i, line in enumerate(open(p, errors="ignore"), 1):
            m = re.match(r"\s*(const|enum|class)\s+(\w+)", line)
            if m and m.group(2) in globals_ and not globals_[m.group(2)].startswith(os.path.relpath(game, arcade)):
                print("%s:%d %s %s  (global in %s)" % (os.path.relpath(p, arcade), i, m.group(1), m.group(2), globals_[m.group(2)]))
