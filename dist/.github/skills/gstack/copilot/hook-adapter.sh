#!/usr/bin/env bash
# Hook preToolUse de gstack-copilot (déclaré dans .github/hooks/gstack-safety.json).
#
# Applique /careful et /freeze sous Copilot, qui ignore les hooks déclarés dans
# un skill. Toujours exit 0 et toujours un objet JSON sur stdout : dans le
# harness Copilot, un hook preToolUse en échec refuse l'outil.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${DIR%/copilot}"

# Chemin rapide, appelé à chaque outil : sans drapeau careful ni frontière
# freeze, aucune décision et aucun processus Python.
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
