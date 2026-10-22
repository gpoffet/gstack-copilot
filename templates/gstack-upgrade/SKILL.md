---
name: gstack-upgrade
description: Explains how this per-project gstack install is updated (gstack-copilot). Reference only, read by the gstack preamble when an update is available.
user-invocable: false
disable-model-invocation: true
---

# gstack updates in a gstack-copilot install

This repository carries a per-project gstack install managed by gstack-copilot.
It is a vendored copy: never try to upgrade it in place (no `git pull`, no
`./setup`, no download into `.github/skills/`).

## Inline upgrade flow

When the preamble printed `UPGRADE_AVAILABLE <old> <new>`:

1. Mention it in one line, without asking a question, then continue the user's
   task: "gstack <new> is available (this repo has <old>). Updates go through
   gstack-copilot: update GSTACK_REF, run build.sh, then install.sh in this repo."
2. Snooze the notice so it is not repeated in every skill run:

```bash
_S=$("$(git rev-parse --show-toplevel)/.github/skills/gstack/bin/gstack-paths" --get GSTACK_STATE_ROOT) && mkdir -p "$_S" && printf '%s %s %s\n' "<new>" 1 "$(date +%s)" > "$_S/update-snoozed"
```

If the user wants no update checks at all:
`"$(git rev-parse --show-toplevel)/.github/skills/gstack/bin/gstack-config" set update_check false`.

When the preamble printed `JUST_UPGRADED <from> <to>`, print
"Running gstack v<to> (just updated!)" and continue.
