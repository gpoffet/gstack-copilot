---
name: gstack-guard
description: |
  Full safety mode: destructive command warnings + directory-scoped edits.
  Combines /careful (warns before rm -rf, DROP TABLE, force-push, etc.) with
  /freeze (blocks edits outside a specified directory). Use for maximum safety
  when touching prod or debugging live systems. Use when asked to "guard mode",
  "full safety", "lock it down", or "maximum safety". (gstack)
disable-model-invocation: true
---
<!-- AUTO-GENERATED from SKILL.md.tmpl — do not edit directly -->
<!-- Regenerate: bun run gen:skill-docs -->


# /guard — Full Safety Mode

Activates both destructive command warnings and directory-scoped edit restrictions.
This is the combination of `/careful` + `/freeze` in a single command.

**Dependency note:** This skill references hook scripts from the sibling `/careful`
and `/freeze` skill directories. Both must be installed (they are installed together
by the gstack setup script).

```bash
GSTACK_STATE_ROOT=$($(git rev-parse --show-toplevel)/.github/skills/gstack/bin/gstack-paths --get GSTACK_STATE_ROOT); : "${GSTACK_STATE_ROOT:?gstack-paths failed; reinstall with ./setup or /gstack-upgrade}"
mkdir -p "$GSTACK_STATE_ROOT"/analytics
echo '{"skill":"guard","ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","repo":"'$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")'"}'  >> "$GSTACK_STATE_ROOT"/analytics/skill-usage.jsonl 2>/dev/null || true
```

## Setup

Ask the user which directory to restrict edits to. Use AskUserQuestion:

- Question: "Guard mode: which directory should edits be restricted to? Destructive command warnings are always on. Files outside the chosen path will be blocked from editing."
- Text input (not multiple choice) — the user types a path.

Once the user provides a directory path:

Set the user-selected boundary with the shared writer, which resolves a physical absolute path and serializes replacement with investigation cleanup:
```bash
[ -d "${GSTACK_ROOT:-/-}/bin" ]&&[ -d "$GSTACK_ROOT/lib" ]||{ _r=$(git rev-parse --show-toplevel 2>/dev/null)/.github/skills/gstack;[ -d "$_r/bin" ]||_r=$(git rev-parse --show-toplevel)/.github/skills/gstack;[ -d "$_r/bin" ]||{ echo "gstack: no install found (tried $_r). Fix: run gstack-copilot's install.sh from the repository root.">&2;exit 1;};GSTACK_ROOT=$_r;}
bash "$GSTACK_ROOT/freeze/bin/freeze-state.sh" set "<user-provided-path>"
```

On helper failure, do not claim the boundary is active. Preserve the state and report recovery; never bypass the shared writer with a direct write or deletion.

Tell the user:
- "**Guard mode active.** Two protections are now running:"
- "1. **Destructive command guard** — rm -rf, DROP TABLE, force-push, etc. warn before executing (overridable); catastrophic shapes (recursive delete of / or ~, force-push to the default branch) are hard-denied"
- "2. **Edit boundary** — file edits restricted to `<path>/`. Edits outside this directory are blocked."
- "To remove the persistent edit boundary, run `/unfreeze`. Ending the session stops its hooks but does not delete that boundary."

## What's protected

See `/careful` for the full list of destructive command patterns and safe exceptions.
See `/freeze` for how edit boundary enforcement works.

## Enforcement on GitHub Copilot (gstack-copilot)

Copilot ignores hooks declared in a skill. gstack-copilot installs a repository
hook instead (`.github/hooks/gstack-safety.json`) that runs the same destructive
command checks before every tool call, but only while the careful flag is set.
Set it now:

```bash
_S=$("$(git rev-parse --show-toplevel)/.github/skills/gstack/bin/gstack-paths" --get GSTACK_STATE_ROOT) && mkdir -p "$_S" && date +%s > "$_S/careful-active" && echo "CAREFUL_ACTIVE: $_S/careful-active"
```

Then tell the user that careful mode is enforced for 12 hours, or until they run
`/gstack-unfreeze` and ask to leave careful mode. If the block fails, or if the
session runs outside the Copilot harness (hooks not loaded), keep the advisory
behavior: pause and confirm with the user before any destructive command.
