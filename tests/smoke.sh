#!/usr/bin/env bash
# tests/smoke.sh: checks dist/, then a real installation into a throwaway repository.
#
# Usage: tests/smoke.sh   (needs git, python3 and bun)
# Nothing is touched outside a temporary folder: GStack state is redirected there.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export GSTACK_STATE_ROOT="$TMP/state"
PASS=0 FAILS=0

ok()   { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
fail() { FAILS=$((FAILS + 1)); printf '  FAIL %s\n' "$1"; [[ -n "${2:-}" ]] && printf '       %s\n' "$2"; }
check() { local name="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$name"; else fail "$name"; fi; }
# expect_decision NAME EXPECTED JSON: EXPECTED is deny, ask or none.
expect_decision() {
  local out got
  out="$(printf '%s' "$3" | bash "$PROJ/.github/skills/gstack/copilot/hook-adapter.sh")"
  local rc=$?
  got="$(printf '%s' "$out" | python3 -I -c 'import json,sys; print(json.load(sys.stdin).get("permissionDecision","none"))' 2>/dev/null || echo invalid)"
  if [[ $rc -eq 0 && "$got" == "$2" ]]; then ok "$1"; else fail "$1" "expected $2, got $got (rc=$rc): $out"; fi
}

echo "== Static checks on dist/"
if python3 -I "$HERE/tests/check_dist.py" "$HERE/dist"; then ok "check_dist"; else fail "check_dist"; fi

echo "== Installation into a throwaway repository"
PROJ="$TMP/project"
mkdir -p "$PROJ" && cd "$PROJ" || exit 1
git init -q && git -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
printf '# Project\n\nHouse rules.\n' > AGENTS.md
cp AGENTS.md "$TMP/AGENTS.orig"
check "install.sh" "$HERE/install.sh" --yes
check "skills copied" test -f .github/skills/gstack-review/SKILL.md
check "hook installed" test -f .github/hooks/gstack-safety.json
check "AGENTS.md section" grep -q 'gstack-copilot:start' AGENTS.md
check "AGENTS.md content kept" grep -q 'House rules' AGENTS.md
cp AGENTS.md "$TMP/AGENTS.1"
check "reinstall" "$HERE/install.sh" --yes
check "reinstall is idempotent" cmp -s AGENTS.md "$TMP/AGENTS.1"

echo "== Binaries"
B=.github/skills/gstack/bin
check "gstack-slug" "$B/gstack-slug"
check "gstack-config set/get" bash -c "'$B/gstack-config' set update_check false && [ \"\$('$B/gstack-config' get update_check)\" = false ]"
check "gstack-redact (Bun)" bash -c "echo test | '$B/gstack-redact'"
check "gstack-next-version (Bun)" "$B/gstack-next-version" --help
echo 1.0.0.0 > VERSION
check "gstack-version-bump write" "$B/gstack-version-bump" write --version 1.0.1.0
check "VERSION written" grep -qx 1.0.1.0 VERSION
rm -f VERSION

echo "== Skill preambles"
for s in review ship office-hours spec investigate; do
  awk '/^```bash$/{f=1;next} /^```$/{if(f) exit} f' ".github/skills/gstack-$s/SKILL.md" > "$TMP/pre.sh"
  out="$(timeout 60 bash "$TMP/pre.sh" 2>&1)"
  if [[ $? -eq 0 && "$out" == *"SKILL_START_PROTO"* ]]; then ok "gstack-$s preamble"; else fail "gstack-$s preamble" "$(printf '%s' "$out" | tail -3)"; fi
done

echo "== /careful and /freeze hook"
ev() { printf '{"toolName":"%s","toolArgs":%s,"cwd":"%s"}' "$1" "$2" "$PROJ"; }
expect_decision "inactive: rm -rf / gets no decision" none "$(ev bash '{"command":"rm -rf /"}')"
expect_decision "invalid input: no decision" none 'not json'
mkdir -p "$GSTACK_STATE_ROOT" && date +%s > "$GSTACK_STATE_ROOT/careful-active"
expect_decision "careful: rm -rf / denied" deny "$(ev bash '{"command":"rm -rf /"}')"
expect_decision "careful: git reset --hard asks" ask "$(ev bash '{"command":"git reset --hard HEAD~1"}')"
expect_decision "careful: ls allowed" none "$(ev bash '{"command":"ls -la"}')"
expect_decision "careful: toolArgs as a JSON string" ask "$(ev bash '"{\"command\":\"git push --force origin main\"}"')"
expect_decision "careful: snake_case format" deny '{"tool_name":"run_in_terminal","tool_input":{"command":"rm -rf ~"}}'
echo 1 > "$GSTACK_STATE_ROOT/careful-active"
expect_decision "careful expired: no decision" none "$(ev bash '{"command":"rm -rf /"}')"
check "careful expired: flag removed" test ! -e "$GSTACK_STATE_ROOT/careful-active"
mkdir -p src other
bash .github/skills/gstack/freeze/bin/freeze-state.sh set "$PROJ/src" >/dev/null 2>&1
expect_decision "freeze: edit inside the boundary" none "$(ev edit '{"path":"src/a.ts"}')"
expect_decision "freeze: edit outside the boundary" deny "$(ev edit '{"path":"other/b.ts"}')"
expect_decision "freeze: apply_patch outside the boundary" deny "$(ev apply_patch '{"input":"*** Begin Patch\n*** Update File: other/c.ts\n*** End Patch"}')"
expect_decision "freeze: reads allowed" none "$(ev view '{"path":"other/b.ts"}')"
bash .github/skills/gstack/freeze/bin/freeze-state.sh clear >/dev/null 2>&1
expect_decision "unfreeze: edit allowed" none "$(ev edit '{"path":"other/b.ts"}')"

echo "== Uninstall"
check "install.sh --uninstall" "$HERE/install.sh" --uninstall
check "skills removed" test ! -e .github/skills/gstack
check "hook removed" test ! -e .github/hooks/gstack-safety.json
check "AGENTS.md restored" cmp -s AGENTS.md "$TMP/AGENTS.orig"

echo "== One-line install (get.sh against a packaged release)"
REL="$TMP/release"
check "scripts/package.sh" "$HERE/scripts/package.sh" "$REL"
GET_PROJ="$TMP/get-project"
mkdir -p "$GET_PROJ" && cd "$GET_PROJ" && git init -q
check "get.sh installs" env GSTACK_COPILOT_URL="file://$REL" bash "$HERE/get.sh" --yes
check "get.sh: skills present" test -f .github/skills/gstack-ship/SKILL.md
check "get.sh --uninstall" env GSTACK_COPILOT_URL="file://$REL" bash "$HERE/get.sh" --uninstall
check "get.sh: skills removed" test ! -e .github/skills/gstack
echo "0000  gstack-copilot.tar.gz" > "$REL/gstack-copilot.tar.gz.sha256"
if env GSTACK_COPILOT_URL="file://$REL" bash "$HERE/get.sh" --yes >/dev/null 2>&1; then
  fail "get.sh rejects a bad checksum"
else
  ok "get.sh rejects a bad checksum"
fi
check "bad checksum: nothing installed" test ! -e .github/skills/gstack

echo
echo "$PASS passed, $FAILS failed"
[[ $FAILS -eq 0 ]]
