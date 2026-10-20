#!/bin/bash
# Build and sign the Android APK, then run the test suite on an exported
# build. Run from anywhere: tools/build_apk.sh [report_dir]
# Clearing .godot/exported matters: a stale export cache once shipped
# scenes without their scripts (games that would not start).
set -e
cd "$(dirname "$0")/.."
GODOT="flatpak run --filesystem=home --filesystem=/tmp org.godotengine.Godot"
rm -rf .godot/exported
# Games are downloads: build the packs that changed (into builds/downloads, the
# "downloads" branch)
# and set the export presets so the APK holds only the launcher. Put the presets
# back afterwards, whatever happens.
trap 'python3 -I tools/packs.py restore' EXIT
python3 -I tools/catalog.py
python3 -I tools/packs.py build --linux sudoku/v1,racing/v1
source <(sed 's/^/K_/' ~/Android/keys/key.txt)
mkdir -p ../builds/linux ../builds/linuxbase
flatpak run --filesystem=home --env=GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$K_keystore" --env=GODOT_ANDROID_KEYSTORE_RELEASE_USER="$K_alias" --env=GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$K_password" org.godotengine.Godot --headless --path . --export-release "Android" ../builds/LabArcade.apk 2>&1 | grep -iE "error" || true
rm -f ../builds/*.idsig
PATH=~/Android/jdk17/bin:$PATH ~/Android/sdk/build-tools/35.0.1/apksigner verify ../builds/LabArcade.apk
# Run the test suite inside a Linux build made by the same export pipeline.
# The build fails (exit 1) if any test fails.
$GODOT --headless --path . --export-debug "LinuxTest" ../builds/linux/LabArcade.x86_64 >/dev/null 2>&1
OUT=${1:-/tmp/labarcade-tests}
mkdir -p "$OUT"
# Headless by default so no game windows pop up; VISUAL=1 also checks drawing.
HEADLESS="--headless"; [ "${VISUAL:-0}" = "1" ] && HEADLESS=""
# Only test what changed since the last release (FULL=1 tests everything).
TEST_ARGS=$(python3 -I tools/changed.py)
echo "Tests: ${TEST_ARGS:-everything}"
timeout 1200 ../builds/linux/LabArcade.x86_64 $HEADLESS --audio-driver Dummy --fixed-fps 60 -- "$OUT" $TEST_ARGS > "$OUT/log.txt" 2>&1 || true
grep -E "^FAIL|^TESTS|SCRIPT ERROR" "$OUT/log.txt" || true
if ! grep -q "^TESTS: .*, 0 failed" "$OUT/log.txt"; then
  echo "TESTS FAILED - see $OUT/report.txt"
  exit 1
fi
# The launcher-only build (like the phone app) must install and play downloaded games.
$GODOT --headless --path . --export-debug "LinuxBase" ../builds/linuxbase/LabArcade.x86_64 >/dev/null 2>&1
timeout 600 ../builds/linuxbase/LabArcade.x86_64 --headless --audio-driver Dummy -- "$OUT" "$(realpath ../builds/linuxpacks)" > "$OUT/pack_log.txt" 2>&1 || true
grep -E "FAIL|PACKTESTS" "$OUT/pack_log.txt" || true
if ! grep -q "^PACKTESTS: .*, 0 failed" "$OUT/pack_log.txt"; then
  echo "PACK TESTS FAILED - see $OUT/pack_report.txt"
  exit 1
fi
cp "$OUT/report.txt" tools/tests/last_report.txt
cp "$OUT/pack_report.txt" tools/tests/last_pack_report.txt
echo "All tests passed. Report: $OUT/report.txt"
