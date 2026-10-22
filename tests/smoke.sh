#!/usr/bin/env bash
# tests/smoke.sh : vérifie dist/ puis une installation réelle dans un dépôt jetable.
#
# Usage : tests/smoke.sh   (nécessite git, python3 et bun)
# Aucun effet hors d'un dossier temporaire : l'état GStack y est redirigé.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export GSTACK_STATE_ROOT="$TMP/state"
PASS=0 FAILS=0

ok()   { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
fail() { FAILS=$((FAILS + 1)); printf '  ECHEC %s\n' "$1"; [[ -n "${2:-}" ]] && printf '        %s\n' "$2"; }
check() { local name="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$name"; else fail "$name"; fi; }
# expect_decision NOM ATTENDU JSON : ATTENDU vaut deny, ask ou none.
expect_decision() {
  local out got
  out="$(printf '%s' "$3" | bash "$PROJ/.github/skills/gstack/copilot/hook-adapter.sh")"
  local rc=$?
  got="$(printf '%s' "$out" | python3 -I -c 'import json,sys; print(json.load(sys.stdin).get("permissionDecision","none"))' 2>/dev/null || echo invalide)"
  if [[ $rc -eq 0 && "$got" == "$2" ]]; then ok "$1"; else fail "$1" "attendu $2, obtenu $got (rc=$rc) : $out"; fi
}

echo "== Contrôles statiques de dist/"
if python3 -I "$HERE/tests/check_dist.py" "$HERE/dist"; then ok "check_dist"; else fail "check_dist"; fi

echo "== Installation dans un dépôt jetable"
PROJ="$TMP/projet"
mkdir -p "$PROJ" && cd "$PROJ" || exit 1
git init -q -b main && git -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
printf '# Projet\n\nRègles maison.\n' > AGENTS.md
cp AGENTS.md "$TMP/AGENTS.orig"
check "install.sh" "$HERE/install.sh" --yes
check "skills copiés" test -f .github/skills/gstack-review/SKILL.md
check "hook installé" test -f .github/hooks/gstack-safety.json
check "section AGENTS.md" grep -q 'gstack-copilot:start' AGENTS.md
check "contenu AGENTS.md conservé" grep -q 'Règles maison' AGENTS.md
cp AGENTS.md "$TMP/AGENTS.1"
check "réinstallation" "$HERE/install.sh" --yes
check "réinstallation idempotente" cmp -s AGENTS.md "$TMP/AGENTS.1"

echo "== Binaires"
B=.github/skills/gstack/bin
check "gstack-slug" "$B/gstack-slug"
check "gstack-config set/get" bash -c "'$B/gstack-config' set update_check false && [ \"\$('$B/gstack-config' get update_check)\" = false ]"
check "gstack-redact (Bun)" bash -c "echo test | '$B/gstack-redact'"
check "gstack-next-version (Bun)" "$B/gstack-next-version" --help
echo 1.0.0.0 > VERSION
check "gstack-version-bump write" "$B/gstack-version-bump" write --version 1.0.1.0
check "VERSION écrit" grep -qx 1.0.1.0 VERSION
rm -f VERSION

echo "== Préambules des skills"
for s in review ship office-hours spec investigate; do
  awk '/^```bash$/{f=1;next} /^```$/{if(f) exit} f' ".github/skills/gstack-$s/SKILL.md" > "$TMP/pre.sh"
  out="$(timeout 60 bash "$TMP/pre.sh" 2>&1)"
  if [[ $? -eq 0 && "$out" == *"SKILL_START_PROTO"* ]]; then ok "préambule gstack-$s"; else fail "préambule gstack-$s" "$(printf '%s' "$out" | tail -3)"; fi
done

echo "== Hook /careful et /freeze"
ev() { printf '{"toolName":"%s","toolArgs":%s,"cwd":"%s"}' "$1" "$2" "$PROJ"; }
expect_decision "inactif : rm -rf / sans décision" none "$(ev bash '{"command":"rm -rf /"}')"
expect_decision "entrée invalide : pas de décision" none 'pas du json'
mkdir -p "$GSTACK_STATE_ROOT" && date +%s > "$GSTACK_STATE_ROOT/careful-active"
expect_decision "careful : rm -rf / refusé" deny "$(ev bash '{"command":"rm -rf /"}')"
expect_decision "careful : git reset --hard demandé" ask "$(ev bash '{"command":"git reset --hard HEAD~1"}')"
expect_decision "careful : ls autorisé" none "$(ev bash '{"command":"ls -la"}')"
expect_decision "careful : toolArgs en chaîne JSON" ask "$(ev bash '"{\"command\":\"git push --force origin main\"}"')"
expect_decision "careful : format snake_case" deny '{"tool_name":"run_in_terminal","tool_input":{"command":"rm -rf ~"}}'
echo 1 > "$GSTACK_STATE_ROOT/careful-active"
expect_decision "careful expiré : pas de décision" none "$(ev bash '{"command":"rm -rf /"}')"
check "careful expiré : drapeau supprimé" test ! -e "$GSTACK_STATE_ROOT/careful-active"
mkdir -p src other
bash .github/skills/gstack/freeze/bin/freeze-state.sh set "$PROJ/src" >/dev/null 2>&1
expect_decision "freeze : edit dans la frontière" none "$(ev edit '{"path":"src/a.ts"}')"
expect_decision "freeze : edit hors frontière" deny "$(ev edit '{"path":"other/b.ts"}')"
expect_decision "freeze : apply_patch hors frontière" deny "$(ev apply_patch '{"input":"*** Begin Patch\n*** Update File: other/c.ts\n*** End Patch"}')"
expect_decision "freeze : lecture autorisée" none "$(ev view '{"path":"other/b.ts"}')"
bash .github/skills/gstack/freeze/bin/freeze-state.sh clear >/dev/null 2>&1
expect_decision "unfreeze : edit autorisé" none "$(ev edit '{"path":"other/b.ts"}')"

echo "== Désinstallation"
check "install.sh --uninstall" "$HERE/install.sh" --uninstall
check "skills retirés" test ! -e .github/skills/gstack
check "hook retiré" test ! -e .github/hooks/gstack-safety.json
check "AGENTS.md restauré" cmp -s AGENTS.md "$TMP/AGENTS.orig"

echo
echo "$PASS réussis, $FAILS en échec"
[[ $FAILS -eq 0 ]]
