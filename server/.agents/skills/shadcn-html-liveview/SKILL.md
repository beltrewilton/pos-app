---
name: shadcn-html-liveview
description: Build Phoenix LiveView interfaces with the vendored, offline shadcn-html components and their documented HTML, ARIA, CSS, and optional JavaScript patterns.
---

# shadcn-html for Phoenix LiveView

Use only the vendored assets in `server/priv/static/assets/ui/`. Do not introduce React, Tailwind, npm component packages, CDNs, remote fonts, or remote icon scripts for these interfaces.

## Workflow

1. Read the applicable component reference under `references/` before composing or changing that component. These files mirror the canonical local `component-skill.md` files.
2. Preserve the documented semantic HTML, class names, `data-*` attributes, ARIA relationships, CSS, and native interaction pattern in HEEx.
3. Use LiveView for server events and validation. Load a component JavaScript file only when its reference requires it, from `/assets/ui/`.
4. Add POS-specific CSS only for layout and composition; never recreate a vendored component's styling.
5. Use `var(--font-numeric)` or `.numeric` for money, quantities, prices, and other numeric POS values. It maps to the locally hosted Google Inter variable font with tabular numerals.

## LiveView forms

- Use a semantic `<form phx-submit=...>` and `Phoenix.HTML.FormField` values.
- Keep matching `label for` and input `id` values.
- Render validation failures with `data-invalid`, `aria-invalid`, and an associated `role="alert"` message as documented by the Form and Input references.
- Do not emit tokens or other secrets in the rendered page.

## References

- [typography.md](references/typography.md)
- [button.md](references/button.md)
- [input.md](references/input.md)
- [label.md](references/label.md)
- [card.md](references/card.md)
- [form.md](references/form.md)
- [separator.md](references/separator.md)
- [alert.md](references/alert.md)
- [dialog.md](references/dialog.md)
- [toast.md](references/toast.md)
- [table.md](references/table.md)
- [select.md](references/select.md)
