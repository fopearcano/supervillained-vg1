#!/usr/bin/env bash
# Rebuilds every generated asset for the Godot port, deterministically.
# Usage (from the repository root): godot/tools/build_assets.sh [path-to-godot]
set -euo pipefail
GODOT_BIN="${1:-${GODOT:-godot}}"
NODE_BIN="${NODE:-node}"
cd "$(dirname "$0")/../.."
"$NODE_BIN" --experimental-transform-types --no-warnings \
  --import ./godot/tools/source_extract/register.mjs godot/tools/source_extract/extract.mjs
"$GODOT_BIN" --headless --path godot --import
"$GODOT_BIN" --headless --path godot --script res://tools/build_resources.gd -- --phase images
"$GODOT_BIN" --headless --path godot --import
"$GODOT_BIN" --headless --path godot --script res://tools/build_resources.gd -- --phase resources
"$GODOT_BIN" --headless --path godot --import
