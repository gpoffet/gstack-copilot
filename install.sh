#!/usr/bin/env bash
# install.sh : installe GStack pour GitHub Copilot dans le dépôt courant.
#
# Usage (depuis la racine du projet cible) :
#   /chemin/gstack-copilot/install.sh              # installe ou met à jour
#   /chemin/gstack-copilot/install.sh --uninstall  # retire tout ce que gstack-copilot a installé
#
# Options :
#   --yes       répond oui aux questions (migration de l'ancien portage incluse)
#   --no-hooks  n'installe pas .github/hooks/gstack-safety.json (/careful et /freeze restent indicatifs)
#   --force     remplace un dossier .github/skills/gstack-* qui ne semble pas géré par gstack-copilot
#
# Copie dist/ (généré par build.sh) : aucune réécriture à l'installation. Idempotent.
set -euo pipefail

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m /!\\ \033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mERREUR:\033[0m %s\n' "$*" >&2; exit 1; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST="$HERE/dist"
MODE=install YES=0 HOOKS=1 FORCE=0
for arg in "$@"; do
  case "$arg" in
    --uninstall) MODE=uninstall ;;
    --yes|-y) YES=1 ;;
    --no-hooks) HOOKS=0 ;;
    --force) FORCE=1 ;;
    -h|--help) sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "option inconnue : $arg (voir --help)" ;;
  esac
done

confirm() {
  [[ $YES -eq 1 ]] && return 0
  [[ -t 0 ]] || return 1
  local r; read -rp "$1 [o/N] " r
  [[ "${r,,}" == o* || "${r,,}" == y* ]]
}

command -v git >/dev/null || die "git est requis"
if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  [[ $MODE == install ]] || die "ce dossier n'est pas un dépôt git"
  warn "Ce dossier n'est pas un dépôt git (les skills GStack en ont besoin)."
  confirm "Initialiser git ici ?" || die "installation annulée"
  git init -q -b main
fi
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
[[ "$ROOT" != "$HERE" ]] || die "lancer install.sh depuis le projet cible, pas depuis gstack-copilot"

SKILLS=.github/skills
MANIFEST="$SKILLS/gstack/.gstack-copilot.json"
HOOK_FILE=.github/hooks/gstack-safety.json
START='<!-- gstack-copilot:start'
END='<!-- gstack-copilot:end -->'

# Noms gérés par l'installation existante (manifest), un par ligne.
managed_names() {
  [[ -f "$MANIFEST" ]] || return 0
  python3 -I -c 'import json,sys; print("\n".join(json.load(open(sys.argv[1])).get("managed", [])))' "$MANIFEST" 2>/dev/null || true
}

# Retire la section gstack-copilot d'AGENTS.md (entre les marqueurs).
strip_agents_section() {
  [[ -f AGENTS.md ]] && grep -qF "$START" AGENTS.md || return 0
  awk -v s="$START" -v e="$END" '
    index($0, s) == 1 { skip = 1; next }
    skip && index($0, e) == 1 { skip = 0; next }
    !skip' AGENTS.md > AGENTS.md.tmp && mv AGENTS.md.tmp AGENTS.md
  # Lignes vides laissées en fin de fichier par la section retirée.
  sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' AGENTS.md > AGENTS.md.tmp && mv AGENTS.md.tmp AGENTS.md
  grep -q '[^[:space:]]' AGENTS.md || : > AGENTS.md
}

remove_managed() {
  local n
  while IFS= read -r n; do
    [[ -n "$n" && "$n" == gstack* && "$n" != */* ]] || continue
    rm -rf "${SKILLS:?}/$n"
  done < <(managed_names)
}

# ------------------------------------------------------------- désinstallation
if [[ $MODE == uninstall ]]; then
  [[ -f "$MANIFEST" ]] || die "aucune installation gstack-copilot trouvée ($MANIFEST absent)"
  say "Suppression des skills gérés"
  remove_managed
  rm -f "$HOOK_FILE"
  rmdir .github/hooks .github/skills .github 2>/dev/null || true
  strip_agents_section
  [[ -f AGENTS.md && ! -s AGENTS.md ]] && rm -f AGENTS.md
  say "GStack retiré de $ROOT. L'état utilisateur (~/.gstack) est conservé."
  exit 0
fi

# ---------------------------------------------------------------- prérequis
[[ -f "$DIST/$SKILLS/gstack/.gstack-copilot.json" ]] || die "dist/ absent ou incomplet : lancer d'abord $HERE/build.sh"
command -v python3 >/dev/null || die "python3 est requis (sudo apt install python3)"

if ! command -v bun >/dev/null && [[ ! -x "$HOME/.bun/bin/bun" ]]; then
  warn "Bun est introuvable : les skills GStack en ont besoin pour leurs outils."
  if confirm "Installer Bun pour cet utilisateur (curl -fsSL https://bun.sh/install | bash) ?"; then
    curl -fsSL https://bun.sh/install | bash
  else
    warn "Installation de Bun ignorée : l'installer avant d'utiliser les skills (https://bun.sh)."
  fi
fi
if ! command -v bun >/dev/null && [[ -x "$HOME/.bun/bin/bun" ]]; then
  warn "Bun est dans ~/.bun/bin mais pas dans le PATH de ce shell : redémarrer VS Code après l'installation."
fi
BUN_MIN=1.4.2
BUN_BIN="$(command -v bun || echo "$HOME/.bun/bin/bun")"
if [[ -x "$BUN_BIN" ]]; then
  BUN_V="$("$BUN_BIN" --version 2>/dev/null || echo 0)"
  if [[ "$(printf '%s\n%s\n' "$BUN_MIN" "$BUN_V" | sort -V | head -1)" != "$BUN_MIN" ]]; then
    warn "Bun $BUN_V est trop ancien (GStack demande $BUN_MIN ou plus) : lancer 'bun upgrade'."
  fi
fi

# ------------------------------------------- migration depuis l'ancien portage
# L'ancien installeur copiait les skills dans .agents/skills/ avec des chemins absolus.
if [[ -f .agents/skills/bin/gstack-config ]]; then
  OLD=()
  for d in .agents/skills/*/; do
    d="${d%/}"
    [[ "$d" == */bin ]] && { OLD+=("$d"); continue; }
    grep -qsE '\(gstack\)|AUTO-GENERATED from SKILL.md.tmpl' "$d/SKILL.md" && OLD+=("$d")
  done
  warn "Ancien portage GStack détecté dans .agents/skills/ (${#OLD[@]} dossiers)."
  warn "Le garder ferait apparaître chaque skill en double dans Copilot."
  if confirm "Supprimer l'ancien portage (.agents/skills/{$(basename -a "${OLD[@]}" | paste -sd, -)}) ?"; then
    rm -rf "${OLD[@]}"
    rm -f .agents/skills/.feature-prompted-* 2>/dev/null || true
    rmdir .agents/skills .agents 2>/dev/null || true
    if [[ -f AGENTS.md ]] && grep -q '^## GStack (skills sous .agents/skills/' AGENTS.md; then
      awk '/^## GStack \(skills sous \.agents\/skills\//{skip=1; next} skip && /^## /{skip=0} !skip' AGENTS.md > AGENTS.md.tmp \
        && mv AGENTS.md.tmp AGENTS.md
      grep -q '[^[:space:]]' AGENTS.md || : > AGENTS.md
    fi
    say "Ancien portage supprimé."
    if [[ -f .vscode/settings.json ]] && grep -q '\.agents/skills' .vscode/settings.json; then
      warn ".vscode/settings.json mentionne encore .agents/skills (chat.tools.terminal.autoApprove) : à nettoyer à la main."
    fi
  else
    warn "Ancien portage conservé : penser à le retirer, les skills apparaîtront en double."
  fi
fi

# ------------------------------------------------------------------ skills
mapfile -t NEW < <(python3 -I -c 'import json,sys; print("\n".join(json.load(open(sys.argv[1]))["managed"]))' "$DIST/$MANIFEST")
mapfile -t PREV < <(managed_names)
for n in "${NEW[@]}"; do
  [[ -e "$SKILLS/$n" ]] || continue
  printf '%s\n' "${PREV[@]}" | grep -qx "$n" && continue
  grep -qs 'AUTO-GENERATED from SKILL.md.tmpl' "$SKILLS/$n/SKILL.md" && continue
  [[ $FORCE -eq 1 ]] || die "$SKILLS/$n existe et n'est pas géré par gstack-copilot (relancer avec --force pour le remplacer)"
done

say "Installation des skills dans $SKILLS/"
remove_managed
mkdir -p "$SKILLS"
for n in "${NEW[@]}"; do
  rm -rf "${SKILLS:?}/$n"
  cp -R "$DIST/$SKILLS/$n" "$SKILLS/$n"
done

if [[ $HOOKS -eq 1 ]]; then
  say "Installation du hook de sécurité ($HOOK_FILE)"
  mkdir -p .github/hooks
  cp "$DIST/$HOOK_FILE" "$HOOK_FILE"
else
  rm -f "$HOOK_FILE"
fi

say "Mise à jour de la section GStack d'AGENTS.md"
strip_agents_section
if [[ -s AGENTS.md ]]; then
  # Une ligne vide entre le contenu existant et la section.
  [[ -z "$(tail -c1 AGENTS.md)" ]] || echo >> AGENTS.md
  [[ -z "$(tail -n1 AGENTS.md)" ]] || echo >> AGENTS.md
fi
cat "$DIST/AGENTS.gstack.md" >> AGENTS.md

# ---------------------------------------------------------------- vérifications
say "Vérifications"
FAIL=0
B="$SKILLS/gstack/bin"
if command -v bun >/dev/null || [[ -x "$HOME/.bun/bin/bun" ]]; then
  PATH="$HOME/.bun/bin:$PATH"
  "$B/gstack-slug" >/dev/null 2>&1 || { warn "gstack-slug ne répond pas"; FAIL=1; }
  echo test | "$B/gstack-redact" >/dev/null 2>&1 || { warn "gstack-redact (Bun) ne démarre pas"; FAIL=1; }
fi
"$B/gstack-config" get proactive >/dev/null 2>&1 || { warn "gstack-config ne répond pas"; FAIL=1; }
if [[ $HOOKS -eq 1 ]]; then
  OUT="$(echo '{"toolName":"bash","toolArgs":{"command":"ls"}}' | bash "$SKILLS/gstack/copilot/hook-adapter.sh")"
  [[ "$OUT" == "{"* ]] || { warn "le hook de sécurité ne répond pas correctement : $OUT"; FAIL=1; }
fi

VERSION="$(python3 -I -c 'import json,sys; m=json.load(open(sys.argv[1])); print(m["gstack_version"], "@", m["gstack_commit"])' "$MANIFEST")"
if [[ $FAIL -ne 0 ]]; then
  die "installation terminée avec des avertissements, voir ci-dessus"
fi
say "GStack $VERSION installé : $(( ${#NEW[@]} - 1 )) skills dans $SKILLS/."
cat <<EOF
    Prochaines étapes :
    1. git add .github AGENTS.md && git commit -m "chore: install gstack-copilot"
    2. Dans VS Code, ouvrir le chat avec "Copilot" comme Session Target
    3. Taper /gstack- pour voir les skills, par exemple /gstack-office-hours
EOF
