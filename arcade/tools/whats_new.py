#!/usr/bin/env python3
"""Turn the newest CHANGELOG.md sections into arcade/whats_new.json for the app's
"What's new" screen, and (with --version-file <path>) write the version.json that
the app checks for updates on the downloads branch.

Usage: python3 -I arcade/tools/whats_new.py [--version-file builds/downloads/version.json]
"""
import json, os, re, sys

ARCADE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
ROOT = os.path.dirname(ARCADE)
APK_URL = "https://github.com/Hephaestus985/Laugh-Labs/raw/downloads/apks/LabArcade.apk"


def plain(s):
    s = re.sub(r"\*\*(.+?)\*\*", r"\1", s)
    s = s.replace("`", "")
    s = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", s)
    return s.strip()


def sections(limit=6):
    text = open(os.path.join(ROOT, "CHANGELOG.md"), encoding="utf-8").read()
    out = []
    for m in re.finditer(r"^## Lab Arcade ([0-9.]+) \(([0-9-]+)\)\n(.*?)(?=^## |\Z)", text, re.M | re.S):
        notes = []
        for line in m.group(3).splitlines():
            if line.startswith("- "):
                notes.append(plain(line[2:]))
            elif line.startswith("  - "):
                notes.append("  - " + plain(line[4:]))
        out.append({"version": m.group(1), "date": m.group(2), "notes": notes})
        if len(out) >= limit:
            break
    return out


def app_version():
    t = open(os.path.join(ARCADE, "project.godot")).read()
    return re.search(r'config/version="([^"]+)"', t).group(1)


def main():
    secs = sections()
    path = os.path.join(ARCADE, "whats_new.json")
    text = json.dumps(secs, indent="\t", ensure_ascii=False) + "\n"
    if not os.path.exists(path) or open(path, encoding="utf-8").read() != text:
        open(path, "w", encoding="utf-8").write(text)
    if "--version-file" in sys.argv:
        vf = sys.argv[sys.argv.index("--version-file") + 1]
        v = app_version()
        cur = next((s for s in secs if s["version"] == v), {"notes": []})
        apk = os.path.join(ROOT, "builds", "LabArcade.apk")
        json.dump({"version": v, "apk": APK_URL, "size": os.path.getsize(apk) if os.path.exists(apk) else 0, "notes": cur["notes"]},
                  open(vf, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    print("whats_new.json: %d versions" % len(secs))


if __name__ == "__main__":
    main()
