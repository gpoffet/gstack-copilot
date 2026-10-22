## Leaving careful mode (gstack-copilot)

On Copilot, `/gstack-careful` and `/gstack-guard` are enforced through a flag
file read by the repository hook. When the user asks to leave careful or guard
mode (not only to unfreeze edits), clear it:

```bash
_S=$("$(git rev-parse --show-toplevel)/.github/skills/gstack/bin/gstack-paths" --get GSTACK_STATE_ROOT) && rm -f "$_S/careful-active" && echo "CAREFUL_CLEARED"
```

For a plain unfreeze, mention that careful mode stays active if it was on, and
that it expires on its own 12 hours after activation.
