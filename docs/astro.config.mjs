// @ts-check
import { defineConfig } from "astro/config";
import starlight from "@astrojs/starlight";

// Docs site for the Rockingham Homelab. The site is a presentation layer:
// ARCHITECTURE.md, CONTEXT.md, the ADRs, and the per-root READMEs stay
// canonical in the repository (see ADR-0010). Deployed to GitHub Pages by
// .github/workflows/deploy-docs.yml; local usage in docs/README.md.
export default defineConfig({
  site: "https://jvcorredor.github.io",
  base: "/homelab",
  integrations: [
    starlight({
      title: "Rockingham Homelab",
      description:
        "How the Rockingham Homelab works: a six-node bare-metal Talos Kubernetes cluster and a Proxmox utility host.",
      social: [
        {
          icon: "github",
          label: "GitHub",
          href: "https://github.com/jvcorredor/homelab",
        },
      ],
      editLink: {
        baseUrl: "https://github.com/jvcorredor/homelab/edit/main/docs/",
      },
      lastUpdated: true,
      sidebar: [
        {
          label: "Start here",
          items: [{ label: "What is Rockingham?", slug: "index" }],
        },
        {
          label: "Architecture",
          items: [
            { label: "The floor", slug: "architecture" },
            { label: "Network and nodes", slug: "architecture/network" },
            { label: "Storage", slug: "architecture/storage" },
            { label: "The utility host", slug: "architecture/utility-host" },
          ],
        },
        {
          label: "Operations",
          items: [
            { label: "Bring-up", slug: "operations/bring-up" },
            { label: "Upgrades and verification", slug: "operations/upgrades" },
          ],
        },
        {
          label: "Cloud and CI",
          items: [
            { label: "GCP project", slug: "cloud/gcp" },
            { label: "CI apply path", slug: "cloud/ci" },
          ],
        },
        {
          label: "Reference",
          items: [
            { label: "Architecture map", slug: "reference/architecture-map" },
            { label: "Glossary", slug: "reference/glossary" },
            { label: "Decision records", slug: "decisions" },
          ],
        },
      ],
    }),
  ],
});
