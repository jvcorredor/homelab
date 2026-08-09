# terraform/bootstrap is split by component for readability. Each step in
# the bootstrap order documented in README.md lives in its own file:
#
#   gateway-api-crds.tf  — step 1: Gateway API CRDs (standard channel)
#   cilium.tf            — step 2: Cilium CNI + LB pool + L2 announcements
#   local-path.tf        — step 3: local-path-provisioner (default StorageClass)
#   metrics-server.tf    — step 4: metrics-server (kubectl top)
#
# This is the barebones floor: Talos + Cilium + local-path + metrics-server,
# nothing else. ArgoCD, ESO, cert-manager, and every app they managed were
# backed out in the 2026-08 teardown (see docs/adr/); anything above this
# floor is re-added deliberately, by hand, as a learning exercise.
#
# Ordering between steps is enforced via `depends_on` on the Helm releases
# and `kubectl_manifest` resources in those files. main.tf is intentionally
# empty of resources — there is nothing that doesn't belong to a numbered
# step.
