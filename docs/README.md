# Docs site

The Starlight site for the Rockingham Homelab, deployed to GitHub Pages at
<https://jvcorredor.github.io/homelab/>.

The site is a **presentation layer, not a source of truth** — see
[ADR-0010](adr/0010-docs-site-with-c4-diagrams.md). `ARCHITECTURE.md`
and `CONTEXT.md` stay canonical at the repo root and are copied into the
site at build time; the ADRs and per-root READMEs are linked, not copied.

## Layout

- `src/content/docs/` — the pages. Everything here is hand-written except
  `src/content/docs/reference/`, which is generated (see below).
- `src/components/Diagram.astro` — wraps a generated C4 diagram with a
  caption and click-to-open-full-size.
- `src/assets/diagrams/` — generated SVGs. Gitignored; produced by
  `scripts/build-diagrams.sh` from `docs/diagrams/workspace.dsl`.
- `diagrams/workspace.dsl` — the Structurizr model. **The only committed
  diagram artifact**; edit this, never an SVG.
- `scripts/sync-repo-docs.mjs` — copies `ARCHITECTURE.md` and `CONTEXT.md`
  into `src/content/docs/reference/`, rewriting relative links to GitHub
  URLs. Runs automatically via `predev` / `prebuild`.

## Local development

Requires Node 22+; rendering diagrams also requires Java 17+ and Graphviz
(`brew install openjdk graphviz`).

```sh
cd docs
npm ci
just diagrams   # from the repo root — renders the C4 SVGs into src/assets/diagrams/
npm run dev     # http://localhost:4321/homelab/
```

`npm run build` fails if the diagram SVGs are missing, so run
`just diagrams` first. `npm run dev` warns in the browser instead.

## Diagrams

The C4 model lives in `docs/diagrams/workspace.dsl`. Editing it is the
only supported way to change a diagram — view keys map to stable asset
names in `scripts/build-diagrams.sh`:

| View key | Asset |
|----------|-------|
| `L1` | `01-system-context.svg` |
| `L2` | `02-containers.svg` |
| `Deployment` | `03-deployment.svg` |
| `Bootstrap` | `04-bootstrap.svg` |
| `LBTraffic` | `05-loadbalancer-flow.svg` |
| `CICD` | `06-ci-apply.svg` |

Rendering uses pinned `structurizr-cli` and PlantUML versions downloaded
into `.tools/` (gitignored) by the script.

## Deploy

`.github/workflows/deploy-docs.yml` builds on PRs (build only) and
deploys on merge to `main` via the `github-pages` environment. Pages must
be configured with **Source: GitHub Actions** in repository settings —
the workflow attempts to enable it on main, but that is UI state no code
holds.
