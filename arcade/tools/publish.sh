#!/bin/bash
# Publish a release after tools/build_apk.sh passed:
#   - main: the source (with catalog.json, packs.json, test reports), tagged arcade-<version>
#   - downloads: the APK and the game packs, as ONE commit that is rewritten each
#     release, so old builds never pile up in the repository's history
# Usage: arcade/tools/publish.sh "<commit message>" [extra tag ...]
#   extra tags are per-game versions, e.g. sudoku-v2
set -e
cd "$(dirname "$0")/../.."
VERSION=$(sed -n 's/^config\/version="\(.*\)"/\1/p' arcade/project.godot)
D=builds/downloads
[ -f builds/LabArcade.apk ] || { echo "build first: arcade/tools/build_apk.sh"; exit 1; }
python3 -I arcade/tools/packs.py ensure
python3 -I arcade/tools/packs.py prune  # keeps packs for this app and the previous one
cp builds/LabArcade.apk "$D/apks/LabArcade.apk"
cp arcade/packs.json "$D/packs.json"
python3 -I arcade/tools/whats_new.py --version-file "$D/version.json"  # the app checks this for updates
N=$(sed -n 2p arcade/tools/tests/last_report.txt | grep -o '^[0-9]*')
[ -n "$N" ] && sed -i -E "s/\([0-9]+ checks\)/($N checks)/" README.md
git add -A
git commit -q -m "$1

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
git tag "arcade-$VERSION"
for t in "${@:2}"; do git tag "$t"; done
git push -q origin main --tags
cd "$D"
git add -A
if git rev-parse -q --verify HEAD >/dev/null; then
  git commit -q --amend -m "Lab Arcade $VERSION downloads"
else
  git commit -q -m "Lab Arcade $VERSION downloads"
fi
git push -q -f origin downloads
echo "Published Lab Arcade $VERSION"
