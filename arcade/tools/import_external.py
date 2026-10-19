#!/usr/bin/env python3
"""Copy a reviewed open-source Godot project into arcade/external/<id>/.

Usage: python3 -I tools/import_external.py <source_checkout> <id> [exclude_glob ...]

- copies the files git tracks (never .git, project.godot, export presets, editor junk)
- rewrites res:// paths to res://external/<id>/
- drops generated lines from .import files so Godot re-imports into the new place
Project settings (autoloads, input actions, physics) must be merged by hand.
"""
import fnmatch, os, re, shutil, subprocess, sys

src, gid, extra = sys.argv[1], sys.argv[2], sys.argv[3:]
dst = os.path.join(os.path.dirname(__file__), "..", "external", gid)
skip = ["project.godot", "export_presets.cfg", ".gitignore", ".gitattributes", "*.tmp", "*.fla", "*.fbx", ".github/*", "*/.gdignore", ".gdignore"] + extra
files = subprocess.check_output(["git", "-C", src, "ls-files", "-z"]).decode().split("\0")
n = 0
for f in files:
    if not f or any(fnmatch.fnmatch(f, p) for p in skip):
        continue
    out = os.path.join(dst, f)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    shutil.copyfile(os.path.join(src, f), out)
    if f.endswith((".gd", ".tscn", ".tres", ".gdshader", ".cfg", ".dtl", ".dch", ".atlastex", ".theme", ".anim")):
        try:
            t = open(out, encoding="utf-8").read()
        except UnicodeDecodeError:
            continue
        open(out, "w", encoding="utf-8").write(t.replace("res://", "res://external/%s/" % gid))
    elif f.endswith(".import"):
        t = open(out, encoding="utf-8").read()
        t = re.sub(r"^(path|dest_files|source_file|path\.[a-z0-9_]+)=.*\n", "", t, flags=re.M)
        open(out, "w", encoding="utf-8").write(t)
    n += 1
print("copied", n, "files to", os.path.normpath(dst))
