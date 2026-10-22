#!/usr/bin/env bash
# build.sh : régénère dist/ à partir de la version de GStack épinglée dans GSTACK_REF.
#
# Usage :
#   ./build.sh                  # clone/met à jour GStack dans .build/gstack
#   ./build.sh /chemin/gstack   # utilise un clone existant (doit être au commit voulu)
#   GSTACK_REF=<sha> ./build.sh # surcharge ponctuelle de la version
#
# Pour passer à une nouvelle version de GStack : mettre le sha dans GSTACK_REF,
# lancer ./build.sh puis tests/smoke.sh, et committer dist/ avec GSTACK_REF.
set -euo pipefail

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mERREUR:\033[0m %s\n' "$*" >&2; exit 1; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v git >/dev/null || die "git est requis"
command -v bun >/dev/null || die "bun est requis pour générer les skills (https://bun.sh)"
command -v python3 >/dev/null || die "python3 est requis"

REF="${GSTACK_REF:-$(tr -d '[:space:]' < "$HERE/GSTACK_REF")}"
[[ -n "$REF" ]] || die "GSTACK_REF est vide"

SRC="${1:-}"
if [[ -z "$SRC" ]]; then
  SRC="$HERE/.build/gstack"
  if [[ ! -d "$SRC/.git" ]]; then
    say "Clonage de GStack dans $SRC"
    mkdir -p "$SRC"
    git -C "$SRC" init -q
    git -C "$SRC" remote add origin https://github.com/garrytan/gstack
  fi
  say "Récupération de GStack @ $REF"
  git -C "$SRC" fetch -q --depth 1 origin "$REF"
  git -C "$SRC" checkout -q --force FETCH_HEAD
  git -C "$SRC" clean -qfdx -e node_modules
fi
SRC="$(cd "$SRC" && pwd)"
[[ -f "$SRC/hosts/copilot.ts" ]] || die "$SRC n'est pas un clone GStack avec le host copilot"

say "Installation des dépendances de génération"
(cd "$SRC" && bun install --frozen-lockfile >/dev/null)

say "Génération des skills (--host copilot)"
(cd "$SRC" && bun run gen:skill-docs --host copilot >/dev/null)

say "Assemblage de dist/"
python3 -I "$HERE/scripts/assemble.py" --src "$SRC" --out "$HERE/dist" --skills "$HERE/skills.txt" --ref "$REF"

say "Terminé. Vérifier avec tests/smoke.sh avant de committer dist/."
