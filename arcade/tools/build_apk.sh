#!/bin/bash
# Build, sign and smoke-test the Android APK. Run from anywhere.
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
# same export pipeline, Linux build, every game played with random input
$GODOT --headless --path . --export-debug "LinuxTest" ../builds/linux/LabArcade.x86_64 >/dev/null 2>&1
OUT=${1:-/tmp/labarcade-smoke}
mkdir -p "$OUT"
../builds/linux/LabArcade.x86_64 --fixed-fps 60 -- "$OUT" 2>&1 | grep -E "SMOKE|ERROR" | sort | uniq -c
