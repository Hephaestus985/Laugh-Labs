#!/usr/bin/env python3
"""Split Lab Arcade into a small launcher APK and one download pack per game version.

Usage (from anywhere): python3 -I arcade/tools/packs.py plan|build|prune|ensure|restore [--linux key,key]

  plan     ask Godot which files the launcher needs (tools/pack_plan.gd) -> builds/pack_plan.json
  build    export every pack that changed (Android), write packs/manifest.json and
           arcade/packs.json (the copy the app trusts), then set up the export presets
           so the APK only holds the launcher
  prune    keep only the packs the newest app and the app before it use
  ensure   make sure builds/downloads holds the "downloads" branch (APK + packs)
  restore  put export_presets.cfg back the way it is in git

Downloads (the APK and the packs) live on the "downloads" branch, checked out at
builds/downloads. That branch is one commit that tools/publish.sh rewrites on every
release, so old builds don't pile up in the repository's history.

A pack is only rebuilt when its source changed: the "src" fingerprint covers the
game's files (and their .import settings) plus the Godot version. An unchanged
pack keeps its exact bytes, so its SHA-256 stays the same and phones that already
downloaded it don't download it again after an app update.
"""
import hashlib, json, os, re, shutil, subprocess, sys

ARCADE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
ROOT = os.path.dirname(ARCADE)
DOWNLOADS = os.path.join(ROOT, "builds", "downloads")
PACKS = os.path.join(DOWNLOADS, "packs")
BUILDS = os.path.join(ROOT, "builds")
PLAN = os.path.join(BUILDS, "pack_plan.json")
PRESETS = os.path.join(ARCADE, "export_presets.cfg")
BACKUP = os.path.join(BUILDS, "export_presets.backup.cfg")
GODOT = ["flatpak", "run", "--filesystem=home", "--filesystem=/tmp", "org.godotengine.Godot"]
FORMAT = "pack-format-1"


def godot(*args, timeout=900):
    return subprocess.run(GODOT + ["--headless", "--path", ARCADE] + list(args), capture_output=True, text=True, timeout=timeout)


def godot_version():
    r = subprocess.run(GODOT + ["--version"], capture_output=True, text=True)
    return r.stdout.strip()


def local(res):
    return os.path.join(ARCADE, res.replace("res://", ""))


def plan():
    os.makedirs(BUILDS, exist_ok=True)
    r = godot("-s", "res://tools/pack_plan.gd", "--", PLAN)
    if not os.path.exists(PLAN):
        sys.exit("pack plan failed:\n" + r.stdout + r.stderr)
    return json.load(open(PLAN))


def uids_of(files):
    """uid://... -> res:// path for a pack's files, so the app can resolve them after loading
    the pack (the launcher's own UID list doesn't know them)."""
    out = {}
    pat = re.compile(r'uid="(uid://[a-z0-9]+)"')
    for f in files:
        lp = local(f)
        cands = [lp + ".uid", lp + ".import"] if not f.endswith((".tscn", ".tres")) else [lp]
        for c in cands:
            if not os.path.exists(c):
                continue
            with open(c, errors="ignore") as fh:
                head = fh.read(4000)
            if c.endswith(".uid"):
                u = head.strip()
                if u.startswith("uid://"):
                    out[u] = f
            else:
                m = pat.search(head)
                if m:
                    out[m.group(1)] = f
    return out


def src_fingerprint(files, version):
    h = hashlib.sha256()
    h.update(FORMAT.encode())
    h.update(version.encode())
    for f in sorted(files):
        h.update(f.encode())
        for p in (local(f), local(f) + ".import"):
            if os.path.exists(p):
                with open(p, "rb") as fh:
                    h.update(fh.read())
    return h.hexdigest()


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def safe(key):
    return key.replace("/", "_")


def packed(lst):
    return "PackedStringArray(" + ", ".join('"%s"' % f for f in lst) + ")"


def write_presets(base_files, pack_files=None, linux_pack_files=None):
    """Rewrite export_presets.cfg: Android = launcher only, plus pack presets."""
    if not os.path.exists(BACKUP):
        shutil.copy(PRESETS, BACKUP)
    t = open(BACKUP).read()
    android = t[t.index("[preset.0]"):t.index("[preset.1]")]
    linux = t[t.index("[preset.1]"):]
    base = list(base_files) + ["res://packs.json"]
    # the launcher APK: only the files the launcher needs
    a = re.sub(r'export_filter="[^"]*"', 'export_filter="resources"\nexport_files=%s' % packed(base), android, count=1)
    if "permissions/internet" not in a:
        a = a.replace("[preset.0.options]\n", "[preset.0.options]\n\npermissions/internet=true\n", 1)
    out = a + linux
    n = 2

    def extra(name, platform, src, files, key_from):
        nonlocal out, n
        body = src.replace("[preset.%d]" % key_from, "[preset.%d]" % n).replace("[preset.%d.options]" % key_from, "[preset.%d.options]" % n)
        body = re.sub(r'name="[^"]*"', 'name="%s"' % name, body, count=1)
        body = re.sub(r'export_filter="[^"]*"', 'export_filter="resources"\nexport_files=%s' % packed(files), body, count=1)
        body = re.sub(r'export_path="[^"]*"', 'export_path=""', body, count=1)
        out += "\n" + body
        n += 1

    extra("AndroidPack", "Android", android, pack_files or [], 0)
    extra("LinuxBase", "Linux", linux, base + ["res://tools/tests/pack_test.tscn", "res://tools/tests/pack_test.gd"], 1)
    out = out.replace('name="LinuxBase"', 'name="LinuxBase"', 1)
    lb = out.rindex('name="LinuxBase"')
    out = out[:lb] + out[lb:].replace('custom_features="smoketest"', 'custom_features="packtest"', 1)
    extra("LinuxPack", "Linux", linux, linux_pack_files or [], 1)
    open(PRESETS, "w").write(out)


def restore():
    if os.path.exists(BACKUP):
        shutil.move(BACKUP, PRESETS)


def export_pack(preset, out_path, base_files, files, linux_files=None):
    write_presets(base_files, files if preset == "AndroidPack" else [], files if preset == "LinuxPack" else [])
    if os.path.exists(out_path):
        os.remove(out_path)
    r = godot("--export-pack", preset, out_path)
    if not os.path.exists(out_path):
        sys.exit("pack export failed for %s:\n%s%s" % (out_path, r.stdout[-2000:], r.stderr[-2000:]))


def ensure():
    """Check out the downloads branch at builds/downloads (it caches the built packs)."""
    if os.path.exists(os.path.join(DOWNLOADS, ".git")):
        return
    os.makedirs(os.path.dirname(DOWNLOADS), exist_ok=True)
    git = ["git", "-C", ROOT]
    subprocess.run(git + ["fetch", "origin", "downloads"], capture_output=True)
    have_local = subprocess.run(git + ["rev-parse", "--verify", "downloads"], capture_output=True).returncode == 0
    have_remote = subprocess.run(git + ["rev-parse", "--verify", "origin/downloads"], capture_output=True).returncode == 0
    if have_local:
        subprocess.run(git + ["worktree", "add", DOWNLOADS, "downloads"], check=True)
    elif have_remote:
        subprocess.run(git + ["worktree", "add", "-b", "downloads", DOWNLOADS, "origin/downloads"], check=True)
    else:
        subprocess.run(git + ["worktree", "add", "--orphan", "-b", "downloads", DOWNLOADS], check=True)
    os.makedirs(PACKS, exist_ok=True)
    os.makedirs(os.path.join(DOWNLOADS, "apks"), exist_ok=True)


def prune():
    """Keep the packs of the new app (arcade/packs.json) and of the previous one
    (builds/downloads/packs.json, still the old list until publish copies the new one)."""
    keep = set()
    for path in (os.path.join(ARCADE, "packs.json"), os.path.join(DOWNLOADS, "packs.json")):
        if os.path.exists(path):
            keep |= {m["file"] for m in json.load(open(path)).values()}
    for f in os.listdir(PACKS):
        if f.endswith(".pck") and f not in keep:
            os.remove(os.path.join(PACKS, f))
            print("removed old pack", f)


def build(linux_keys):
    restore()  # a crashed earlier run may have left generated presets behind
    ensure()
    p = plan()
    version = godot_version()
    os.makedirs(PACKS, exist_ok=True)
    mpath = os.path.join(PACKS, "manifest.json")
    old = json.load(open(mpath)) if os.path.exists(mpath) else {}
    manifest = {}
    for key, info in sorted(p["packs"].items()):
        files = info["files"]
        src = src_fingerprint(files, version)
        prev = old.get(key)
        if prev and prev.get("src") == src and os.path.exists(os.path.join(PACKS, prev["file"])):
            prev["uids"] = uids_of(files)
            manifest[key] = prev
            print("unchanged  %-28s %s" % (key, prev["file"]))
            continue
        tmp = os.path.join(BUILDS, safe(key) + ".pck")
        export_pack("AndroidPack", tmp, p["base"], files)
        sha = sha256(tmp)
        name = "%s-%s.pck" % (safe(key), sha[:12])
        shutil.move(tmp, os.path.join(PACKS, name))
        manifest[key] = {"file": name, "sha256": sha, "size": os.path.getsize(os.path.join(PACKS, name)), "src": src, "scene": info["scene"], "uids": uids_of(files)}
        print("built      %-28s %s (%.1f MB)" % (key, name, manifest[key]["size"] / 1e6))
    json.dump(manifest, open(mpath, "w"), indent=1, sort_keys=True)
    app = {k: {"file": v["file"], "sha256": v["sha256"], "size": v["size"], "scene": v["scene"], "uids": v.get("uids", {})} for k, v in manifest.items()}
    json.dump(app, open(os.path.join(ARCADE, "packs.json"), "w"), indent=1, sort_keys=True)
    # Linux packs for the pack test (not published)
    for key in linux_keys:
        out = os.path.join(BUILDS, "linuxpacks", safe(key) + ".pck")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        export_pack("LinuxPack", out, p["base"], p["packs"][key]["files"])
    linux_sha = {k: sha256(os.path.join(BUILDS, "linuxpacks", safe(k) + ".pck")) for k in linux_keys}
    json.dump(linux_sha, open(os.path.join(BUILDS, "linuxpacks", "sha.json"), "w"), indent=1)
    write_presets(p["base"])
    total = sum(m["size"] for m in manifest.values())
    print("packs: %d, %.1f MB in total" % (len(manifest), total / 1e6))


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    linux = []
    if "--linux" in sys.argv:
        linux = sys.argv[sys.argv.index("--linux") + 1].split(",")
    if cmd == "plan":
        plan()
    elif cmd == "build":
        build(linux)
    elif cmd == "restore":
        restore()
    elif cmd == "prune":
        prune()
    elif cmd == "ensure":
        ensure()
    else:
        sys.exit(__doc__)
