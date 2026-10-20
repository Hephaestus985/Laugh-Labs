#!/usr/bin/env python3
"""Add autoloads and input actions of an imported game to arcade/project.godot.

Usage: python3 -I tools/add_project_settings.py <section> <file_with_lines>
The file holds lines in project.godot format (e.g. `Name="*res://..."` for
[autoload], or `action={ ... }` blocks for [input]). Existing keys are replaced.
"""
import re, sys

sec, src = sys.argv[1], sys.argv[2]
p = __file__.rsplit("/tools/", 1)[0] + "/project.godot"
t = open(p).read()
add = open(src).read().strip("\n") + "\n"
keys = re.findall(r"^([A-Za-z0-9_]+)=", add, re.M)
m = re.search(r"^\[%s\]\n" % re.escape(sec), t, re.M)
if not m:
    t = t.rstrip("\n") + "\n\n[%s]\n\n" % sec
    m = re.search(r"^\[%s\]\n" % re.escape(sec), t, re.M)
start = m.end()
nxt = re.search(r"^\[", t[start:], re.M)
end = start + nxt.start() if nxt else len(t)
body = t[start:end]
for k in keys:  # drop an older definition of the same key (single line or {...} block)
    body = re.sub(r"^%s=(\{.*?\n\}\n|.*\n)" % re.escape(k), "", body, flags=re.M | re.S)
body = body.rstrip("\n") + "\n" + add + "\n"
t = t[:start] + body + t[end:]
open(p, "w").write(t)
print("added", len(keys), "keys to [%s]" % sec)
