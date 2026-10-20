#!/usr/bin/env python3
"""Build arcade/catalog.json from every game's arcade_info.json, and check them.

Usage: python3 -I arcade/tools/catalog.py [--check]

Each game describes itself in its own folder:
  arcade/games/<id>/arcade_info.json      games made for the arcade
  arcade/external/<id>/arcade_info.json   games by others
Adding a game = adding its folder (with arcade_info.json and its version folders).
The launcher reads catalog.json (games.gd); this script keeps it in sync and stops
with a clear message when an entry is broken. --check only validates.
"""
import json, os, re, sys

ARCADE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
REQUIRED = ["id", "name", "tagline", "about", "controls", "length", "effort", "publisher", "genre", "color", "versions"]


def local(res):
    return os.path.join(ARCADE, res.replace("res://", ""))


def load(kind):
    root = os.path.join(ARCADE, "games" if kind == "lab" else "external")
    out, errors = [], []
    for name in sorted(os.listdir(root)):
        p = os.path.join(root, name, "arcade_info.json")
        if not os.path.exists(p):
            continue
        try:
            g = json.load(open(p))
        except ValueError as e:
            errors.append("%s: not valid JSON (%s)" % (p, e))
            continue
        where = "%s/%s" % (os.path.basename(root), name)
        for k in REQUIRED:
            if k not in g:
                errors.append("%s: missing \"%s\"" % (where, k))
        if g.get("id") != name:
            errors.append("%s: id \"%s\" must match the folder name" % (where, g.get("id")))
        if not re.fullmatch(r"#[0-9a-fA-F]{6}", str(g.get("color", ""))):
            errors.append("%s: color must look like #3366cc" % where)
        vs = g.get("versions", [])
        if not vs:
            errors.append("%s: needs at least one version" % where)
        nums = [v.get("v") for v in vs]
        if nums != sorted(nums) or len(set(nums)) != len(nums):
            errors.append("%s: versions must be listed oldest first, each number once" % where)
        for v in vs:
            for k in ["v", "date", "scene", "notes"]:
                if k not in v:
                    errors.append("%s v%s: missing \"%s\"" % (where, v.get("v"), k))
            if "scene" in v and not os.path.exists(local(v["scene"])):
                errors.append("%s v%s: scene %s does not exist" % (where, v.get("v"), v["scene"]))
        for k in ["main", "park"]:
            if k in g and not os.path.exists(local(g[k])):
                errors.append("%s: %s file %s does not exist" % (where, k, g[k]))
        out.append(g)
    out.sort(key=lambda g: (g.get("order", 9999), g.get("id", "")))
    return out, errors


def main():
    lab, e1 = load("lab")
    ext, e2 = load("external")
    errors = e1 + e2
    ids = [g.get("id") for g in lab + ext]
    for i in set(ids):
        if ids.count(i) > 1:
            errors.append("game id \"%s\" is used twice" % i)
    if errors:
        sys.exit("catalog problems:\n  " + "\n  ".join(errors))
    if "--check" in sys.argv:
        print("catalog ok: %d + %d games" % (len(lab), len(ext)))
        return
    text = json.dumps({"lab": lab, "external": ext}, indent="\t", ensure_ascii=False) + "\n"
    path = os.path.join(ARCADE, "catalog.json")
    if not os.path.exists(path) or open(path).read() != text:
        open(path, "w").write(text)
        print("catalog.json updated: %d + %d games" % (len(lab), len(ext)))
    else:
        print("catalog.json up to date: %d + %d games" % (len(lab), len(ext)))


if __name__ == "__main__":
    main()
