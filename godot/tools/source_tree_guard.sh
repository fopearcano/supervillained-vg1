#!/usr/bin/env bash
# Source-tree guard (MILESTONES.md common gate 5): only /godot and docs/porting may differ from the
# audited PixiJS source commit. Run from anywhere inside the repository.
set -euo pipefail
AUDITED=95b69c04c5c3b9626e49719f8f916a44659cd265
cd "$(git rev-parse --show-toplevel)"
changed=$(git diff --name-only "$AUDITED" -- . ':(exclude)godot' ':(exclude)docs/porting'; git ls-files --others --exclude-standard -- . ':(exclude)godot' ':(exclude)docs/porting')
if [ -n "$changed" ]; then
  echo "source-tree guard FAILED: files outside /godot and docs/porting differ from $AUDITED:"
  echo "$changed"
  exit 1
fi
echo "source-tree guard OK: only /godot and docs/porting differ from $AUDITED"
