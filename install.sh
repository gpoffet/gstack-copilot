#!/usr/bin/env bash
# install.sh: installs GStack for GitHub Copilot into the current git repository.
#
# Usage (from the root of the target project):
#   /path/to/gstack-copilot/install.sh              # install or update
#   /path/to/gstack-copilot/install.sh --uninstall  # remove everything gstack-copilot installed
#
# Options:
#   --yes       answer yes to every question (including removal of the legacy port)
#   --no-hooks  skip .github/hooks/gstack-safety.json (/careful and /freeze become advisory)
#   --force     replace a .github/skills/gstack-* folder that gstack-copilot does not manage
#
# Copies dist/ (produced by build.sh) as is: nothing is rewritten at install time.
# Idempotent. Compatible with the bash 3.2 shipped by macOS.
set -euo pipefail

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m /!\\ \033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST="$HERE/dist"
MODE=install YES=0 HOOKS=1 FORCE=0
for arg in "$@"; do
  case "$arg" in
    --uninstall) MODE=uninstall ;;
    --yes|-y) YES=1 ;;
    --no-hooks) HOOKS=0 ;;
    --force) FORCE=1 ;;
    -h|--help) sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option: $arg (see --help)" ;;
  esac
done

confirm() {
  [[ $YES -eq 1 ]] && return 0
  [[ -t 0 ]] || return 1
  local r; read -rp "$1 [y/N] " r
  case "$r" in [yY]*) return 0 ;; *) return 1 ;; esac
}

command -v git >/dev/null || die "git is required"
if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  [[ $MODE == install ]] || die "this folder is not a git repository"
  warn "This folder is not a git repository (GStack skills need one)."
  confirm "Run git init here?" || die "installation cancelled"
  git init -q
fi
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
[[ "$ROOT" != "$HERE" ]] || die "run install.sh from the target project, not from gstack-copilot itself"

SKILLS=.github/skills
MANIFEST="$SKILLS/gstack/.gstack-copilot.json"
HOOK_FILE=.github/hooks/gstack-safety.json
START='<!-- gstack-copilot:start'
END='<!-- gstack-copilot:end -->'

# Names listed in a manifest's "managed" field, one per line.
manifest_names() {
  [[ -f "$1" ]] || return 0
  python3 -I -c 'import json,sys; print("\n".join(json.load(open(sys.argv[1])).get("managed", [])))' "$1" 2>/dev/null || true
}

# Drops trailing blank lines; empties a file that only holds whitespace.
trim_trailing_blank() {
  awk '{ line[NR] = $0 } NF { last = NR } END { for (i = 1; i <= last; i++) print line[i] }' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
}

# Removes the gstack-copilot section of AGENTS.md (between the markers).
strip_agents_section() {
  [[ -f AGENTS.md ]] && grep -qF "$START" AGENTS.md || return 0
  awk -v s="$START" -v e="$END" '
    index($0, s) == 1 { skip = 1; next }
    skip && index($0, e) == 1 { skip = 0; next }
    !skip' AGENTS.md > AGENTS.md.tmp && mv AGENTS.md.tmp AGENTS.md
  trim_trailing_blank AGENTS.md
}

remove_managed() {
  local n
  for n in $(manifest_names "$MANIFEST"); do
    case "$n" in gstack|gstack-*) rm -rf "${SKILLS:?}/$n" ;; esac
  done
}

# ------------------------------------------------------------------ uninstall
if [[ $MODE == uninstall ]]; then
  [[ -f "$MANIFEST" ]] || die "no gstack-copilot installation found ($MANIFEST is missing)"
  say "Removing managed skills"
  remove_managed
  rm -f "$HOOK_FILE"
  rmdir .github/hooks .github/skills .github 2>/dev/null || true
  strip_agents_section
  [[ -f AGENTS.md && ! -s AGENTS.md ]] && rm -f AGENTS.md
  say "GStack removed from $ROOT. User state (~/.gstack) is kept."
  exit 0
fi

# ------------------------------------------------------------- requirements
[[ -f "$DIST/$MANIFEST" ]] || die "dist/ is missing or incomplete: run $HERE/build.sh first"
command -v python3 >/dev/null || die "python3 is required"

if ! command -v bun >/dev/null && [[ ! -x "$HOME/.bun/bin/bun" ]]; then
  warn "Bun was not found: GStack skills need it for their tools."
  if confirm "Install Bun for this user (curl -fsSL https://bun.sh/install | bash)?"; then
    curl -fsSL https://bun.sh/install | bash
  else
    warn "Bun not installed: install it before using the skills (https://bun.sh)."
  fi
fi
if ! command -v bun >/dev/null && [[ -x "$HOME/.bun/bin/bun" ]]; then
  warn "Bun is in ~/.bun/bin but not on this shell's PATH: restart VS Code after installing."
fi
BUN_MIN=1.4.2
BUN_BIN="$(command -v bun || echo "$HOME/.bun/bin/bun")"
if [[ -x "$BUN_BIN" ]]; then
  BUN_V="$("$BUN_BIN" --version 2>/dev/null || echo 0)"
  if [[ "$(printf '%s\n%s\n' "$BUN_MIN" "$BUN_V" | sort -V | head -1)" != "$BUN_MIN" ]]; then
    warn "Bun $BUN_V is too old (GStack needs $BUN_MIN or later): run 'bun upgrade'."
  fi
fi

# ------------------------------------------------- legacy port migration
# The legacy installer (install-gstack.sh) copied skills into .agents/skills/
# with absolute paths. Keeping it would list every skill twice in Copilot.
if [[ -f .agents/skills/bin/gstack-config ]]; then
  OLD=()
  for d in .agents/skills/*/; do
    d="${d%/}"
    if [[ "$d" == */bin ]] || grep -qsE '\(gstack\)|AUTO-GENERATED from SKILL.md.tmpl' "$d/SKILL.md"; then
      OLD+=("$d")
    fi
  done
  warn "Legacy GStack port found in .agents/skills/ (${#OLD[@]} folders)."
  warn "Keeping it would list every skill twice in Copilot."
  if [[ ${#OLD[@]} -gt 0 ]] && confirm "Remove it (.agents/skills/{$(basename -a "${OLD[@]}" | paste -sd, -)})?"; then
    rm -rf "${OLD[@]}"
    rm -f .agents/skills/.feature-prompted-* 2>/dev/null || true
    rmdir .agents/skills .agents 2>/dev/null || true
    # Its AGENTS.md section had no markers: it ran until the next "## " heading.
    if [[ -f AGENTS.md ]] && grep -q '^## GStack (skills sous .agents/skills/' AGENTS.md; then
      awk '/^## GStack \(skills sous \.agents\/skills\//{skip=1; next} skip && /^## /{skip=0} !skip' AGENTS.md > AGENTS.md.tmp \
        && mv AGENTS.md.tmp AGENTS.md
      trim_trailing_blank AGENTS.md
    fi
    say "Legacy port removed."
    if [[ -f .vscode/settings.json ]] && grep -q '\.agents/skills' .vscode/settings.json; then
      warn ".vscode/settings.json still mentions .agents/skills (chat.tools.terminal.autoApprove): clean it up by hand."
    fi
  else
    warn "Legacy port kept: remove it later, or skills will show up twice."
  fi
fi

# --------------------------------------------------------------------- skills
NEW="$(manifest_names "$DIST/$MANIFEST")"
PREV="$(manifest_names "$MANIFEST")"
for n in $NEW; do
  [[ -e "$SKILLS/$n" ]] || continue
  printf '%s\n' "$PREV" | grep -qx "$n" && continue
  grep -qs 'AUTO-GENERATED from SKILL.md.tmpl' "$SKILLS/$n/SKILL.md" && continue
  [[ $FORCE -eq 1 ]] || die "$SKILLS/$n exists and is not managed by gstack-copilot (use --force to replace it)"
done

say "Installing skills into $SKILLS/"
remove_managed
mkdir -p "$SKILLS"
COUNT=0
for n in $NEW; do
  rm -rf "${SKILLS:?}/$n"
  cp -R "$DIST/$SKILLS/$n" "$SKILLS/$n"
  [[ "$n" == gstack ]] || COUNT=$((COUNT + 1))
done

if [[ $HOOKS -eq 1 ]]; then
  say "Installing the safety hook ($HOOK_FILE)"
  mkdir -p .github/hooks
  cp "$DIST/$HOOK_FILE" "$HOOK_FILE"
else
  rm -f "$HOOK_FILE"
fi

say "Updating the GStack section of AGENTS.md"
strip_agents_section
if [[ -s AGENTS.md ]]; then
  # Exactly one blank line between existing content and the section.
  trim_trailing_blank AGENTS.md
  [[ -s AGENTS.md ]] && echo >> AGENTS.md
fi
cat "$DIST/AGENTS.gstack.md" >> AGENTS.md

# ---------------------------------------------------------------------- checks
say "Checking the installation"
FAIL=0
B="$SKILLS/gstack/bin"
if command -v bun >/dev/null || [[ -x "$HOME/.bun/bin/bun" ]]; then
  PATH="$HOME/.bun/bin:$PATH"
  "$B/gstack-slug" >/dev/null 2>&1 || { warn "gstack-slug does not respond"; FAIL=1; }
  echo test | "$B/gstack-redact" >/dev/null 2>&1 || { warn "gstack-redact (Bun) does not start"; FAIL=1; }
fi
"$B/gstack-config" get proactive >/dev/null 2>&1 || { warn "gstack-config does not respond"; FAIL=1; }
if [[ $HOOKS -eq 1 ]]; then
  OUT="$(echo '{"toolName":"bash","toolArgs":{"command":"ls"}}' | bash "$SKILLS/gstack/copilot/hook-adapter.sh")"
  [[ "$OUT" == "{"* ]] || { warn "the safety hook returned an unexpected answer: $OUT"; FAIL=1; }
fi
[[ $FAIL -eq 0 ]] || die "installation finished with warnings, see above"

VERSION="$(python3 -I -c 'import json,sys; m=json.load(open(sys.argv[1])); print(m["gstack_version"], "@", m["gstack_commit"])' "$MANIFEST")"
say "GStack $VERSION installed: $COUNT skills in $SKILLS/."
cat <<EOF
    Next steps:
    1. git add .github AGENTS.md && git commit -m "chore: install gstack-copilot"
    2. In VS Code, open the chat with "Copilot" as the Session Target
    3. Type /gstack- to list the skills, for example /gstack-office-hours
EOF
