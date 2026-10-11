# CLAUDE.md

Guidance for agents working in this repository.

Read [`ARCHITECTURE.md`](./ARCHITECTURE.md) first — it is the live-system
map and the entry point to everything else. [`CONTEXT.md`](./CONTEXT.md)
is the canonical glossary; [`docs/adr/`](./docs/adr/README.md) holds the
decisions (ADR-0002 and ADR-0004 are in force; ADR-0012 is the current
frame, and ADR-0009 still defines the floor).

The homelab is the RaptGroup platform's dev and incubation cluster
(ADR-0012). Install, upgrade, and operate layers yourself; do not ask the
operator to install one by hand. Before adding a layer above the floor,
check it against the admission test in ADR-0012: a named consumer,
declared in git, and a health signal.
