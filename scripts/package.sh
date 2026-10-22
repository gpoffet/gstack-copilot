#!/usr/bin/env bash
# scripts/package.sh: builds the release archive downloaded by get.sh.
#
# Usage: scripts/package.sh <output folder>
# Produces gstack-copilot.tar.gz (a gstack-copilot/ folder holding install.sh,
# dist/, LICENSE and the READMEs) and gstack-copilot.tar.gz.sha256.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$(mkdir -p "${1:?usage: scripts/package.sh <output folder>}" && cd "$1" && pwd)"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

[[ -f "$HERE/dist/.github/skills/gstack/.gstack-copilot.json" ]] || { echo "dist/ is missing: run ./build.sh" >&2; exit 1; }

mkdir "$STAGE/gstack-copilot"
cp -R "$HERE/dist" "$HERE/install.sh" "$HERE/LICENSE" "$HERE/README.md" "$HERE/README.fr.md" "$STAGE/gstack-copilot/"
tar -czf "$OUT/gstack-copilot.tar.gz" -C "$STAGE" gstack-copilot
(cd "$OUT" && { sha256sum gstack-copilot.tar.gz 2>/dev/null || shasum -a 256 gstack-copilot.tar.gz; } > gstack-copilot.tar.gz.sha256)
echo "$OUT/gstack-copilot.tar.gz ($(du -h "$OUT/gstack-copilot.tar.gz" | cut -f1))"
