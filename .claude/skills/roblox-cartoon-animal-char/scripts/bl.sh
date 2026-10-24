#!/bin/sh
# Headless Blender, Windows-safe: shadows the _wmi module (a hung winmgmt service freezes Blender's Python
# at startup). Usage: sh bl.sh script.py [-- script args]
# BLENDER env var overrides the executable path.
HERE="$(cd "$(dirname "$0")" && pwd)"
BL="${BLENDER:-/c/Program Files/Blender Foundation/Blender 5.2/blender.exe}"
SCRIPT="$1"; shift
PYTHONPATH="$HERE/nowmi" timeout "${BL_TIMEOUT:-900}" "$BL" -b --factory-startup --python-use-system-env --python "$SCRIPT" "$@"
