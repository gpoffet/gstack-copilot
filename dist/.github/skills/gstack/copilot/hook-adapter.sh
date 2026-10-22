#!/usr/bin/env bash
# gstack-copilot preToolUse hook (declared in .github/hooks/gstack-safety.json).
#
# Enforces /careful and /freeze under Copilot, which ignores hooks declared in a
# skill. Always exits 0 and always prints one JSON object: in the Copilot
# harness, a failing preToolUse hook denies the tool.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${DIR%/copilot}"

# Fast path, run on every tool call: with no careful flag and no freeze
# boundary there is nothing to decide, and no Python process is started.
STATE=""
if . "$ROOT/bin/gstack-state-root.sh" 2>/dev/null && command -v gstack_state_root >/dev/null 2>&1; then
  STATE="$(gstack_state_root 2>/dev/null; printf x)"; STATE="${STATE%x}"
fi
if [ -n "$STATE" ] && [ ! -f "$STATE/careful-active" ] && [ ! -f "$STATE/freeze-dir.txt" ]; then
  cat >/dev/null
  echo '{}'
  exit 0
fi

if command -v python3 >/dev/null 2>&1; then
  OUT="$(GSTACK_COPILOT_STATE="$STATE" python3 -I "$DIR/hook_adapter.py" 2>/dev/null)"
  case "$OUT" in
    "{"*) printf '%s\n' "$OUT" ;;
    *) echo '{}' ;;
  esac
else
  cat >/dev/null
  echo '{}'
fi
exit 0
