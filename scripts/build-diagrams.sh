#!/usr/bin/env bash
# Render the Structurizr C4 workspace to SVGs for the docs site.
#
# docs/diagrams/workspace.dsl is the only committed diagram artifact.
# This script downloads pinned build tools into .tools/ (gitignored),
# exports every view to C4-PlantUML, and renders each one to an SVG in
# docs/src/assets/diagrams/ (gitignored). The docs deploy workflow runs
# it before the Astro build; locally it needs Java 17+ and Graphviz.
#
# Usage: scripts/build-diagrams.sh

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

STRUCTURIZR_CLI_VERSION="v2025.11.09"
PLANTUML_VERSION="1.2026.8"

workspace="docs/diagrams/workspace.dsl"
assets_dir="$repo_root/docs/src/assets/diagrams"
tools_dir="$repo_root/.tools"

# View keys (set explicitly in workspace.dsl) mapped to stable asset names.
views=(
  "L1:01-system-context"
  "L2:02-containers"
  "Deployment:03-deployment"
  "Bootstrap:04-bootstrap"
  "LBTraffic:05-loadbalancer-flow"
  "CICD:06-ci-apply"
)

fail() { echo "build-diagrams: $*" >&2; exit 1; }

command -v java  >/dev/null 2>&1 || fail "Java 17+ is required (https://adoptium.net/)"
command -v dot   >/dev/null 2>&1 || fail "Graphviz is required (brew install graphviz / apt-get install graphviz)"
command -v curl  >/dev/null 2>&1 || fail "curl is required"
command -v unzip >/dev/null 2>&1 || fail "unzip is required"

# --- Pinned tools, cached under .tools/ ------------------------------------

cli_dir="$tools_dir/structurizr-cli-$STRUCTURIZR_CLI_VERSION"
if [[ ! -f "$cli_dir/structurizr.sh" ]]; then
  echo "Downloading structurizr-cli $STRUCTURIZR_CLI_VERSION"
  tmp_zip="$(mktemp)"
  curl -fsSL -o "$tmp_zip" \
    "https://github.com/structurizr/cli/releases/download/$STRUCTURIZR_CLI_VERSION/structurizr-cli.zip"
  rm -rf "$cli_dir"
  mkdir -p "$cli_dir"
  unzip -q "$tmp_zip" -d "$cli_dir"
  chmod +x "$cli_dir/structurizr.sh"
  rm -f "$tmp_zip"
fi

plantuml_jar="$tools_dir/plantuml-$PLANTUML_VERSION.jar"
if [[ ! -f "$plantuml_jar" ]]; then
  echo "Downloading PlantUML $PLANTUML_VERSION"
  mkdir -p "$tools_dir"
  curl -fsSL -o "$plantuml_jar" \
    "https://github.com/plantuml/plantuml/releases/download/v$PLANTUML_VERSION/plantuml-$PLANTUML_VERSION.jar"
fi

# --- Export + render -------------------------------------------------------

puml_dir="$(mktemp -d)"
trap 'rm -rf "$puml_dir"' EXIT

echo "Exporting views from $workspace"
"$cli_dir/structurizr.sh" export \
  -workspace "$workspace" \
  -format plantuml/c4plantuml \
  -output "$puml_dir" >/dev/null

mkdir -p "$assets_dir"
for pair in "${views[@]}"; do
  key="${pair%%:*}"
  name="${pair##*:}"
  puml="$(find "$puml_dir" -name "*-${key}.puml" -print -quit)"
  [[ -n "$puml" ]] || fail "no export for view key '$key' — check workspace.dsl"

  echo "Rendering $key -> docs/src/assets/diagrams/$name.svg"
  java -jar "$plantuml_jar" -charset UTF-8 -tsvg "$puml" >/dev/null
  mv "${puml%.puml}.svg" "$assets_dir/$name.svg"
done

echo "Done: ${#views[@]} diagrams in docs/src/assets/diagrams/"
