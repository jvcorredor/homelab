default:
    @just --list

# Run post-bootstrap smoke tests against the current kubeconfig context
smoke: smoke-cilium

# cilium-cli's test namespaces — `cilium-test-1` plus the `cilium-test-ccnp*`
# pair for the CiliumClusterwideNetworkPolicy tests — would otherwise inherit
# Talos's cluster-wide PodSecurity default (`enforce: baseline`), which
# rejects the test fixtures: they need NET_RAW, hostNetwork, and hostPort.
# cilium-cli's `--namespace-labels` flag reaches only the primary namespace,
# so pre-create all of them `privileged` instead — cilium-cli reuses an
# existing namespace as-is. Names track cilium-cli's convention for the
# default `--test-concurrency 1`.
#
# Two checks are excluded as unreliable on this homelab, so `just smoke`
# stays a clean pass/fail gate:
#   - no-unexpected-packet-drops trips on ambient VLAN-tagged LAN traffic
#     that Cilium drops by design ("VLAN traffic disallowed by VLAN filter").
#   - check-log-errors scans the full agent log and re-flags benign
#     startup noise.
smoke-cilium:
    #!/usr/bin/env bash
    set -euo pipefail
    for ns in cilium-test-1 cilium-test-ccnp1 cilium-test-ccnp2; do
      kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
      kubectl label namespace "$ns" --overwrite \
        pod-security.kubernetes.io/enforce=privileged \
        pod-security.kubernetes.io/warn=privileged \
        pod-security.kubernetes.io/audit=privileged
    done
    cilium connectivity test --test '!no-unexpected-packet-drops' --test '!check-log-errors'

# Check that relative links in the live docs (ARCHITECTURE.md, CONTEXT.md) resolve
check-docs:
    scripts/check-docs.sh
