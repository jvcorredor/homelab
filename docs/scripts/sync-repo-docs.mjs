// Sync the canonical repository docs into the site as generated pages.
//
// ARCHITECTURE.md and CONTEXT.md stay the source of truth at the repo
// root. This script copies them into src/content/docs/reference/ with
// frontmatter and rewrites their relative links to GitHub URLs, so the
// rendered pages point at files the site does not serve. The generated
// files are gitignored and recreated by `prebuild` / `predev`, which
// keeps the site from drifting from the repo.

import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const docsDir = join(dirname(fileURLToPath(import.meta.url)), "..");
const repoRoot = join(docsDir, "..");
const outDir = join(docsDir, "src", "content", "docs", "reference");

const REPO = "jvcorredor/homelab";
const BRANCH = "main";
const BLOB = `https://github.com/${REPO}/blob/${BRANCH}/`;
const EDIT = `https://github.com/${REPO}/edit/${BRANCH}/`;

const pages = [
  {
    source: "ARCHITECTURE.md",
    target: "architecture-map.md",
    title: "Architecture map",
    description:
      "The live-system map: what is running, where it is configured, and where facts live. Generated from ARCHITECTURE.md at build time.",
  },
  {
    source: "CONTEXT.md",
    target: "glossary.md",
    title: "Glossary",
    description:
      "The canonical vocabulary used across the repository. Generated from CONTEXT.md at build time.",
  },
];

function rewriteLinks(markdown) {
  return markdown.replace(/\]\(([^)\s]+)\)/g, (match, target) => {
    if (/^(https?:|mailto:|#)/.test(target)) return match;
    const [path, hash] = target.split("#");
    const suffix = hash ? `#${hash}` : "";
    return `](${BLOB}${path.replace(/^\.\//, "")}${suffix})`;
  });
}

await mkdir(outDir, { recursive: true });

for (const page of pages) {
  const body = await readFile(join(repoRoot, page.source), "utf8");
  const withoutTitle = body.replace(/^# .*\n/, "");
  const markdown = [
    "---",
    `title: ${JSON.stringify(page.title)}`,
    `description: ${JSON.stringify(page.description)}`,
    `editUrl: ${JSON.stringify(`${EDIT}${page.source}`)}`,
    "---",
    "",
    `<!-- Generated from ${page.source} by docs/scripts/sync-repo-docs.mjs. Do not edit this copy. -->`,
    "",
    rewriteLinks(withoutTitle),
  ].join("\n");

  await writeFile(join(outDir, page.target), markdown);
  console.log(`sync-repo-docs: ${page.source} -> src/content/docs/reference/${page.target}`);
}
