---
name: gstack-unfreeze
description: |
  Clear the freeze boundary set by /freeze, allowing edits to all directories
  again. Use when you want to widen edit scope without ending the session.
  Use when asked to "unfreeze", "unlock edits", "remove freeze", or
  "allow all edits". (gstack)
disable-model-invocation: true
---
<!-- AUTO-GENERATED from SKILL.md.tmpl — do not edit directly -->
<!-- Regenerate: bun run gen:skill-docs -->

# /unfreeze — Clear Freeze Boundary

Remove the edit restriction set by `/freeze`, allowing edits to all directories.

```bash
GSTACK_STATE_ROOT=$($(git rev-parse --show-toplevel)/.github/skills/gstack/bin/gstack-paths --get GSTACK_STATE_ROOT); : "${GSTACK_STATE_ROOT:?gstack-paths failed; reinstall with ./setup or /gstack-upgrade}"
mkdir -p "$GSTACK_STATE_ROOT"/analytics
echo '{"skill":"unfreeze","ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","repo":"'$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")'"}'  >> "$GSTACK_STATE_ROOT"/analytics/skill-usage.jsonl 2>/dev/null || true
```

## Clear the boundary

```bash
[ -d "${GSTACK_ROOT:-/-}/bin" ]&&[ -d "$GSTACK_ROOT/lib" ]||{ _r=$(git rev-parse --show-toplevel 2>/dev/null)/.github/skills/gstack;[ -d "$_r/bin" ]||_r=$(git rev-parse --show-toplevel)/.github/skills/gstack;[ -d "$_r/bin" ]||{ echo "gstack: no install found (tried $_r). Fix: run gstack-copilot's install.sh from the repository root.">&2;exit 1;};GSTACK_ROOT=$_r;}
bash "$GSTACK_ROOT/freeze/bin/freeze-state.sh" clear
```

This is explicit user-requested removal, not investigation cleanup. The shared writer serializes it with acquisition, replacement and owner-checked release. On `FREEZE_BUSY` or unexpected state, leave everything untouched and report recovery; never delete state or a possibly active mutation lock directly.

Tell the user the result. Note that `/freeze` hooks are still registered for the
session — they will just allow everything since no state file exists. To re-freeze,
run `/freeze` again.

## Leaving careful mode (gstack-copilot)

On Copilot, `/gstack-careful` and `/gstack-guard` are enforced through a flag
file read by the repository hook. When the user asks to leave careful or guard
mode (not only to unfreeze edits), clear it:

```bash
_S=$("$(git rev-parse --show-toplevel)/.github/skills/gstack/bin/gstack-paths" --get GSTACK_STATE_ROOT) && rm -f "$_S/careful-active" && echo "CAREFUL_CLEARED"
```

For a plain unfreeze, mention that careful mode stays active if it was on, and
that it expires on its own 12 hours after activation.
