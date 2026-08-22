---
name: shadcn-html-liveview
description: Build Phoenix LiveView interfaces with the vendored framework-agnostic shadcn-html components and their documented HTML, ARIA, CSS, and optional JavaScript patterns.
---

# shadcn-html for Phoenix LiveView

Use the vendored shadcn-html assets in `server/priv/static/assets/shadcn-html/` for LiveView UI. This is a static HTML/CSS system: do not introduce React, Tailwind, npm component packages, or a build step for these components.

## Workflow

1. Read the applicable component reference under `references/` before composing a component.
2. Preserve the documented class names, data attributes, semantic HTML, and ARIA relationships in HEEx.
3. Use LiveView for server events and validation. Keep browser JavaScript only for a component's documented client-side behavior.
4. Include only the component styles needed by the rendered page. The root layout already includes the vendored form-related assets.

## LiveView forms

- Use a semantic `<form phx-submit=...>` and `Phoenix.HTML.FormField` values.
- Keep matching `label for` and input `id` values.
- Render validation failures with `data-invalid`, `aria-invalid`, and an associated `role="alert"` message as documented in [form.md](references/form.md).
- Do not emit tokens or other secrets in the rendered page.

## References

- [button.md](references/button.md)
- [card.md](references/card.md)
- [form.md](references/form.md)
- [input.md](references/input.md)
- [label.md](references/label.md)
