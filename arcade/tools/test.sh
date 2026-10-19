#!/bin/bash
# Lab Arcade debug/test mode: runs the test suite with no window and no sound.
#   tools/test.sh            everything (launcher, all games, games by others)
#   tools/test.sh menu       launcher only
#   tools/test.sh external   games by others only
#   tools/test.sh only=sudoku,minesweeper   just those games
# VISUAL=1 tools/test.sh ... opens a silent window far off-screen and also checks
# that every game draws something (screenshots land in the report folder).
cd "$(dirname "$0")/.."
GODOT="flatpak run --filesystem=home --filesystem=/tmp org.godotengine.Godot"
OUT=${OUT:-/tmp/labarcade-tests}
mkdir -p "$OUT"
MODE="--headless"; [ "${VISUAL:-0}" = "1" ] && MODE="--position 6000,6000 --resolution 960x540"
timeout ${TIMEOUT:-1200} $GODOT $MODE --audio-driver Dummy --path . --fixed-fps 60 res://tools/tests/run_tests.tscn -- "$OUT" "$@" > "$OUT/log.txt" 2>&1
grep -E "^FAIL|^TESTS|SCRIPT ERROR" "$OUT/log.txt"
grep -q "^TESTS: .*, 0 failed" "$OUT/log.txt"
