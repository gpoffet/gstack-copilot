#!/usr/bin/env bash
# build.sh: regenerates dist/ from the GStack commit pinned in GSTACK_REF.
#
# Usage:
#   ./build.sh                  # clones or updates GStack in .build/gstack
#   ./build.sh /path/to/gstack  # uses an existing clone (checked out at the wanted commit)
#   GSTACK_REF=<sha> ./build.sh # one-off override of the pinned commit
#
# To move to a new GStack version: put its sha in GSTACK_REF, run ./build.sh
# then tests/smoke.sh, and commit dist/ together with GSTACK_REF.
set -euo pipefail

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v git >/dev/null || die "git is required"
command -v bun >/dev/null || die "bun is required to render the skills (https://bun.sh)"
command -v python3 >/dev/null || die "python3 is required"

REF="${GSTACK_REF:-$(tr -d '[:space:]' < "$HERE/GSTACK_REF")}"
[[ -n "$REF" ]] || die "GSTACK_REF is empty"

SRC="${1:-}"
if [[ -z "$SRC" ]]; then
  SRC="$HERE/.build/gstack"
  if [[ ! -d "$SRC/.git" ]]; then
    say "Cloning GStack into $SRC"
    mkdir -p "$SRC"
    git -C "$SRC" init -q
    git -C "$SRC" remote add origin https://github.com/garrytan/gstack
  fi
  say "Fetching GStack @ $REF"
  git -C "$SRC" fetch -q --depth 1 origin "$REF"
  git -C "$SRC" checkout -q --force FETCH_HEAD
  git -C "$SRC" clean -qfdx -e node_modules
fi
SRC="$(cd "$SRC" && pwd)"
[[ -f "$SRC/hosts/copilot.ts" ]] || die "$SRC is not a GStack clone with the copilot host"

say "Installing generator dependencies"
(cd "$SRC" && bun install --frozen-lockfile >/dev/null)

say "Rendering skills (--host copilot)"
(cd "$SRC" && bun run gen:skill-docs --host copilot >/dev/null 2>&1) || die "gen:skill-docs --host copilot failed"

say "Assembling dist/"
python3 -I "$HERE/scripts/assemble.py" --src "$SRC" --out "$HERE/dist" --skills "$HERE/skills.txt" --ref "$REF"

say "Done. Run tests/smoke.sh before committing dist/."
