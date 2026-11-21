#!/usr/bin/env bash
# Rebuilds (or with --check verifies) every generated asset for the Godot port, deterministically.
# Usage (from the repository root): godot/tools/build_assets.sh [--check] [path-to-godot]
# Needs the pinned Node (godot/tools/.node-version; override with NODE=...) and `npm ci`.
set -euo pipefail
CHECK=""
if [ "${1:-}" = "--check" ]; then CHECK="--check"; shift; fi
GODOT_BIN="${1:-${GODOT:-godot}}"
NODE_BIN="${NODE:-node}"
cd "$(dirname "$0")/../.."
"$NODE_BIN" --experimental-transform-types --no-warnings \
  --import ./godot/tools/source_extract/register.mjs godot/tools/source_extract/extract.mjs $CHECK
"$GODOT_BIN" --headless --path godot --import
if [ -n "$CHECK" ]; then
  "$GODOT_BIN" --headless --path godot --script res://tools/build_resources.gd -- --phase all --check
else
  "$GODOT_BIN" --headless --path godot --script res://tools/build_resources.gd -- --phase images
  "$GODOT_BIN" --headless --path godot --import
  "$GODOT_BIN" --headless --path godot --script res://tools/build_resources.gd -- --phase resources
  "$GODOT_BIN" --headless --path godot --import
fi
