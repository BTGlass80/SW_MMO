# Asset Factory Feedback Queue

This folder is for feedback on generated asset-factory artifacts after Claude, Codex, or a human designer tries them in context.

Use this when the message is not a new asset request, but a response such as:

- this worked great;
- this did not import;
- this is visually wrong in the runtime camera;
- this needs different collision;
- this is too expensive;
- this should become the new baseline.

## Folder Contract

```text
feedback/
  README.md
  inbox/
  reviewed/
  actioned/
```

Submit feedback in:

```text
feedback/inbox/FB-YYYYMMDD-short-kebab-name.md
```

Use:

```text
../FEEDBACK_TEMPLATE.md
```

Codex should move or copy reviewed feedback into `feedback/reviewed/`, then create a follow-up asset request or update docs when action is needed. If a feedback item triggers a new generation pass, record that pass in the normal `requests/` queue or generated review docs.

