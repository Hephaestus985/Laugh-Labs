#!/usr/bin/env python3
"""Write and sign the game list ("store") that the app downloads, so games can be
updated or added without a new app. Run after tools/packs.py build.

Usage: python3 -I arcade/tools/store.py launcher|games|check

  launcher  for a release with a new app (tools/publish.sh): the store matches the
            app's own lists, serial = build * 1000, and the launcher's code is noted
  games     for a games-only release (GAMES_ONLY=1 tools/publish.sh): the next serial;
            refused when the launcher's own files changed since the last app release
            (that needs a new app: the games would rely on code phones don't have)
  check     only the "launcher files unchanged" test, for tools/build_apk.sh

Writes builds/downloads/store.json, store.sig (RSA-SHA256 with the key in
~/Android/keys/store_sign.key, which never goes into the repository) and art/ (covers
and screenshots, for games the app doesn't have yet). The app's public key is in
common/store.gd. builds/downloads/launcher.json remembers the last app release.
"""
import hashlib, json, os, re, shutil, subprocess, sys

ARCADE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
ROOT = os.path.dirname(ARCADE)
DOWNLOADS = os.path.join(ROOT, "builds", "downloads")
PLAN = os.path.join(ROOT, "builds", "pack_plan.json")
KEY = os.path.expanduser("~/Android/keys/store_sign.key")
PUB = os.path.expanduser("~/Android/keys/store_sign.pub")
FORMAT = 1


def local(res):
    return os.path.join(ARCADE, res[len("res://"):])


def build_number():
    return int(re.search(r"config/build=(\d+)", open(os.path.join(ARCADE, "project.godot")).read()).group(1))


def base_fingerprint():
    """The launcher's own files (what's inside the APK, except the game lists)."""
    plan = json.load(open(PLAN))
    h = hashlib.sha256()
    for f in sorted(plan["base"]):
        if f in ("res://catalog.json", "res://packs.json", "res://whats_new.json") or "/shots/" in f or f.endswith("/cover.jpg"):
            continue  # lists and pictures: a store brings newer ones
        h.update(f.encode())
        p = local(f)
        if os.path.exists(p):
            h.update(open(p, "rb").read())
    t = open(os.path.join(ARCADE, "project.godot")).read()
    h.update(re.sub(r"config/(version|build)=.*", "", t).encode())  # autoloads, input actions
    return h.hexdigest()


def art_files(catalog):
    art = {}
    os.makedirs(os.path.join(DOWNLOADS, "art"), exist_ok=True)
    keep = set()
    for kind in ("lab", "external"):
        for g in catalog.get(kind, []):
            for path in [g.get("cover", "")] + list(g.get("shots", [])):
                if not path or not os.path.exists(local(path)):
                    continue
                data = open(local(path), "rb").read()
                sha = hashlib.sha256(data).hexdigest()
                name = "art/%s-%s.jpg" % (g["id"], sha[:16])
                if not os.path.exists(os.path.join(DOWNLOADS, name)):
                    open(os.path.join(DOWNLOADS, name), "wb").write(data)
                keep.add(name)
                art[path] = {"file": name, "sha256": sha}
    for f in os.listdir(os.path.join(DOWNLOADS, "art")):
        if "art/" + f not in keep:
            os.remove(os.path.join(DOWNLOADS, "art", f))
    return art


def sign(path):
    sig = path[:-len(".json")] + ".sig"
    subprocess.run(["openssl", "dgst", "-sha256", "-sign", KEY, "-out", sig, path], check=True)
    r = subprocess.run(["openssl", "dgst", "-sha256", "-verify", PUB, "-signature", sig, path], capture_output=True, text=True)
    if "Verified OK" not in r.stdout:
        sys.exit("store signature does not verify: " + r.stdout + r.stderr)


def launcher_info():
    p = os.path.join(DOWNLOADS, "launcher.json")
    return json.load(open(p)) if os.path.exists(p) else {}


def check_games_only():
    last = launcher_info()
    if not last:
        sys.exit("no app release with a game list yet: publish a new app first")
    if last.get("build") != build_number():
        sys.exit("project.godot has build %d but the last app release is %s: a games-only release keeps the app's build number" % (build_number(), last.get("build")))
    if last.get("base") != base_fingerprint():
        sys.exit("the launcher's own files changed since the last app release (shared code, the launcher, project settings): this needs a new app (tools/publish.sh without GAMES_ONLY)")


def make(mode):
    catalog = json.load(open(os.path.join(ARCADE, "catalog.json")))
    packs = json.load(open(os.path.join(ARCADE, "packs.json")))
    build = build_number()
    old_path = os.path.join(DOWNLOADS, "store.json")
    old = json.load(open(old_path)) if os.path.exists(old_path) else {}
    if mode == "games":
        check_games_only()
        serial = max(int(old.get("serial", 0)) + 1, build * 1000 + 1)
    else:
        serial = build * 1000
    store = {"format": FORMAT, "serial": serial, "build": build, "catalog": catalog, "packs": packs, "art": art_files(catalog)}
    json.dump(store, open(old_path, "w"), indent=None, separators=(",", ":"), sort_keys=True, ensure_ascii=False)
    sign(old_path)
    if mode == "launcher":
        json.dump({"build": build, "base": base_fingerprint()}, open(os.path.join(DOWNLOADS, "launcher.json"), "w"), indent=1)
    print("store.json: serial %d, %d packs, signed" % (serial, len(packs)))


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd in ("launcher", "games"):
        make(cmd)
    elif cmd == "check":
        check_games_only()
        print("launcher files unchanged since the last app release")
    else:
        sys.exit(__doc__)
