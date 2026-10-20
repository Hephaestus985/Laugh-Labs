#!/bin/bash
# Publish a release after tools/build_apk.sh passed:
#   - main: the source (with catalog.json, packs.json, test reports), tagged arcade-<version>
#   - downloads: the APK, the game packs and the signed game list (store.json), as ONE
#     commit that is rewritten each release, so old builds never pile up in the history
# Usage: arcade/tools/publish.sh "<commit message>" [extra tag ...]
#   extra tags are per-game versions, e.g. sudoku-v2
# GAMES_ONLY=1 (after GAMES_ONLY=1 tools/build_apk.sh): game updates without a new app.
#   Phones get them from the signed game list; no APK, tagged games-<serial>.
set -e
cd "$(dirname "$0")/../.."
VERSION=$(sed -n 's/^config\/version="\(.*\)"/\1/p' arcade/project.godot)
D=builds/downloads
python3 -I arcade/tools/packs.py ensure
python3 -I arcade/tools/packs.py prune  # keeps packs for this app, the previous one and the online list
if [ "${GAMES_ONLY:-0}" = "1" ]; then
  python3 -I arcade/tools/store.py games  # refuses when the launcher's files changed
  TAG=""
else
  [ -f builds/LabArcade.apk ] || { echo "build first: arcade/tools/build_apk.sh"; exit 1; }
  cp builds/LabArcade.apk "$D/apks/LabArcade.apk"
  cp arcade/packs.json "$D/packs.json"  # the new app's own list
  python3 -I arcade/tools/whats_new.py --version-file "$D/version.json"  # the app checks this for updates
  python3 -I arcade/tools/store.py launcher
  TAG="arcade-$VERSION"
fi
[ -n "$TAG" ] || TAG="games-$(python3 -c 'import json;print(json.load(open("builds/downloads/store.json"))["serial"])')"
N=$(sed -n 2p arcade/tools/tests/last_report.txt | grep -o '^[0-9]*')
[ -n "$N" ] && sed -i -E "s/\([0-9]+ checks\)/($N checks)/" README.md
git add -A
git commit -q -m "$1

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
git tag "$TAG"
for t in "${@:2}"; do git tag "$t"; done
git push -q origin main --tags
cd "$D"
git add -A
if git rev-parse -q --verify HEAD >/dev/null; then
  git commit -q --amend -m "Lab Arcade $VERSION downloads ($TAG)"
else
  git commit -q -m "Lab Arcade $VERSION downloads ($TAG)"
fi
git push -q -f origin downloads
echo "Published $TAG"
