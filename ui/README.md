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
