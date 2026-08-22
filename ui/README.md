# Offline UI kit

`ui/shadcn-html/` is the checked-in source of the selected shadcn-html components. Every component folder includes its required `component-skill.md`; read that file before adding or changing an interface. Preserve its semantic HTML, ARIA, classes, `data-*` variants, CSS, and any documented native interaction pattern. POS CSS may compose components into a screen layout, but must not recreate component styling.

The baseline is loaded in this order: `default-semantic-tokens.css`, `fonts/inter.css`, then component CSS in the order in each runtime's root document. Component JavaScript is loaded only for components that need it. Inter is hosted locally and is the numeric font (`.numeric`, with tabular numerals).

Runtime copies are deliberately static:

- Tauri: `client/src/vendor/ui/`
- Phoenix/LiveView: `server/priv/static/assets/ui/`

Do not use CDN URLs, npm UI packages, remote fonts, or remote icon scripts at runtime. The only supported refresh operation is:

```sh
./scripts/update-ui-assets.sh
```

The script downloads pinned shadcn-html, Lucide, and Google-hosted Inter sources, verifies the expected component files, mirrors them into both runtimes, and writes `ui/manifest.txt` with version data and SHA-256 checksums. To refresh from a reviewed local shadcn-html checkout, set `SHADCN_HTML_SOURCE_DIR` to its root before running the command.

## UI requirement prompt examples

### 1. Add a POS discount dialog

> Add a discount action to the Tauri order panel. Before implementation, read the local Button, Dialog, Input, Label, Form, and Alert `component-skill.md` files under `ui/shadcn-html/components/`. Use their documented semantic HTML, ARIA, `data-*` variants, CSS, and Dialog JS exactly. Keep discount calculation and printing behavior in the existing POS JavaScript. Use POS-specific CSS only to position the action in the order layout; do not recreate component styles. Use `.numeric` for all monetary values. Do not add npm packages, CDNs, remote fonts, or remote icons.

### 2. Build a LiveView product table

> Create a Phoenix LiveView product-management page with a filter input, category select, product table, and destructive delete confirmation. Read the local Input, Label, Select, Table, Button, Alert, and Dialog component skill files before writing HEEx. Use the existing `/assets/ui/` static assets and preserve every documented class, ARIA relationship, and `data-*` variant. Keep filtering, validation, and deletion in LiveView events. Load Dialog JS only if its documented browser interaction is needed. Format prices and inventory values with `.numeric`; do not introduce Tailwind, React, or third-party UI packages.

### 3. Add an offline checkout confirmation

> Add an offline checkout confirmation flow shared in presentation between Tauri and Phoenix. Read the local Card, Separator, Button, Alert, Toast, and Typography component skills first. Compose the confirmation summary from those components without overriding their styles; write only layout CSS specific to the POS screen. The checkout confirmation must use semantic headings, an accessible status/error alert, and tabular Inter numerals for totals. Preserve existing business logic and APIs. Runtime assets must remain local: use `client/src/vendor/ui/` for Tauri and `/assets/ui/` for Phoenix, with no CDN or remote script/font requests.
