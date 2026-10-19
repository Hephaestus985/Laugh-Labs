#!/bin/bash
# Build and sign the Android APK, then run the test suite on an exported
# build. Run from anywhere: tools/build_apk.sh [report_dir]
# Clearing .godot/exported matters: a stale export cache once shipped
# scenes without their scripts (games that would not start).
set -e
cd "$(dirname "$0")/.."
GODOT="flatpak run --filesystem=home --filesystem=/tmp org.godotengine.Godot"
rm -rf .godot/exported
source <(sed 's/^/K_/' ~/Android/keys/key.txt)
mkdir -p ../builds/linux
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
timeout 1200 ../builds/linux/LabArcade.x86_64 $HEADLESS --fixed-fps 60 -- "$OUT" > "$OUT/log.txt" 2>&1 || true
grep -E "^FAIL|^TESTS|SCRIPT ERROR" "$OUT/log.txt" || true
if ! grep -q "^TESTS: .*, 0 failed" "$OUT/log.txt"; then
  echo "TESTS FAILED - see $OUT/report.txt"
  exit 1
fi
echo "All tests passed. Report: $OUT/report.txt"
