# ADR-0010: Documentation site with C4 diagrams as a repo-layer artifact

- **Status:** Accepted
- **Date:** 2026-09-12

## Context

The 2026-08-09 reset ([ADR-0009](./0009-barebones-reset.md)) removed the
previous docs site along with everything above the floor. That was right
for the cluster: the site arrived with the rest of the agent-installed
automation, and its dependabot noise was part of what the reset ended.

What remains is a documentation contract rather than a reading
experience. [`ARCHITECTURE.md`](../../ARCHITECTURE.md) states structure,
never values; [`CONTEXT.md`](../../CONTEXT.md) owns vocabulary;
[ADRs](./README.md) own decisions; the per-root READMEs own procedures.
The contract serves the repository well, but it has two gaps. There is
no browsable entry point — no navigation, no search. And nothing is
visual: node layout, the Cilium data path, the bootstrap order, and the
CI apply boundary are all prose and tables.

The operator wants a site whose purpose is understanding the live
system, with C4-model diagrams rendered from a source model rather than
hand-drawn images. Mermaid is not the preferred notation for this; the
C4 model expressed in Structurizr DSL is.

This is a repo-layer addition — markdown, a Node build, a Pages deploy.
It adds no running component, so it does not re-open ADR-0009's cluster
decision.

## Decision

Add an Astro Starlight site under `docs/`, deployed to GitHub Pages
(`https://jvcorredor.github.io/homelab`) by a workflow that runs on
changes under `docs/`.

The site is a **presentation layer, not a source of truth**.
`ARCHITECTURE.md`, `CONTEXT.md`, the ADRs, and the per-root READMEs
remain canonical in the repository. The reference pages that mirror
`ARCHITECTURE.md` and `CONTEXT.md` are generated from those files at
build time — with relative links rewritten to GitHub URLs — so they
cannot drift. Site-native pages explain with diagrams and link out to
the owning files for values.

Diagrams are C4 views defined in one Structurizr DSL workspace at
[`docs/diagrams/workspace.dsl`](../diagrams/workspace.dsl). That file is
the only committed diagram artifact. The deploy workflow renders it with
a pinned `structurizr-cli` (C4-PlantUML export) and a pinned PlantUML to
SVGs, which the site build consumes; generated diagram assets are not
committed. The initial views are system context, container, deployment
(nodes and network), and dynamic views for Talos bring-up,
LoadBalancer service traffic, and the CI apply path.

The dependency surface is deliberately two packages (`astro`,
`@astrojs/starlight`) with a committed lockfile and `npm ci` in CI. No
comment hosting, no CMS, no analytics, no search service beyond what
Starlight ships.

## Consequences

**Positive**

- The live system gains a browsable, searchable reading experience, and
  the diagrams render from a model rather than from images that rot
  silently.
- The structure-vs-values doctrine is preserved: values still live in
  their owning files, and the site links to them.
- No generated assets are committed; editing the DSL and merging flows
  straight to the published site.
- The cluster is untouched, so ADR-0009's admission price does not
  apply to this addition.

**Negative / ongoing**

- Two toolchains to keep current: the Astro/Starlight line and the
  pinned structurizr-cli/PlantUML versions in the workflow. Both are
  pinned; updates are deliberate.
- Diagrams carry values (addresses, ranges) to be useful, which is a
  drift surface `ARCHITECTURE.md` does not have. The DSL must be updated
  alongside the files that own those values.
- CI gains a Java toolchain step and depends on downloading pinned JARs
  from GitHub releases at build time.
- Pages must be enabled, and the `github-pages` environment exists, as
  repository UI state that no code holds.
- If the site ever grows a dependency tree, it recreates the conditions
  ADR-0009 ended. The two-package rule is the guard; changing it is a
  new decision.

## Alternatives Considered

### Structurizr Site Generator instead of Starlight

Rejected. It publishes a parallel site centered on the model. Diagrams
would be first-class, but navigation, search, and the canonical repo
docs would not integrate — two sites to maintain, with the prose living
in the wrong one.

### Render diagrams with Kroki (kroki.io or a CI container)

Rejected for the build path. It adds a network dependency on an external
rendering service — or a Docker stack in CI — on every deploy, and
embedding DSL inside content pages makes views hard to reuse. Acceptable
as a local preview technique, not as the deployed pipeline.

### Commit exported SVGs

Rejected. Binary artifacts in git with no review surface, plus a
regeneration step that can be forgotten: the diagrams would silently rot
in exactly the way this decision exists to prevent.

### Mermaid diagrams

Rejected. The operator does not want Mermaid C4 diagrams; Structurizr
DSL keeps one model separate from view selection and yields consistent
C4 output across views.

### D2 or Terraform-graph tooling

Rejected as the primary notation. Those generate adjacency, not the C4
abstractions (systems, containers, nodes), and would document Terraform
structure rather than the live system. They may appear later as
complements.

### Hosted documentation (GitBook, Notion, and similar)

Rejected. Another account and another surface, with content drifting
from the repo. GitHub Pages builds from the same commit as the docs it
describes.
