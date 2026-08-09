variable "kubeconfig_path" {
  description = "Path to the Talos-issued kubeconfig used by the kubernetes/helm/kubectl providers. Default points at the conventional talos/_out location."
  type        = string
  default     = "../../talos/_out/kubeconfig"
}

variable "kube_context" {
  description = "Optional kubeconfig context to use. Leave empty to use the file's current-context."
  type        = string
  default     = ""
}

variable "lb_pool_start" {
  description = "First IP in the CiliumLoadBalancerIPPool range. Sits above the Optimum DHCP scope and the static cluster range."
  type        = string
  default     = "192.168.1.200"
}

variable "lb_pool_end" {
  description = "Last IP in the CiliumLoadBalancerIPPool range."
  type        = string
  default     = "192.168.1.230"
}

variable "control_plane_node_selector" {
  description = "Label key used to identify Talos control-plane nodes for L2-announcement exclusion. Matches the Talos default."
  type        = string
  default     = "node-role.kubernetes.io/control-plane"
}

# --- Chart / manifest version pins ----------------------------------------

variable "gateway_api_version" {
  description = "Tag (with leading v) of kubernetes-sigs/gateway-api whose experimental-install.yaml is applied. Must be supported by the chosen Cilium version — Cilium 1.19 supports Gateway API v1.4.1."
  type        = string
  default     = "v1.4.1"
}

variable "cilium_chart_version" {
  description = "Cilium Helm chart version (matches the Cilium minor). Cilium does not support skipping minor versions on upgrade — bump one minor at a time and `tofu apply` between each (see \"Upgrading Cilium\" in the README). The staged walk off the unsupported 1.16.5 / Kubernetes 1.36 pairing (#196, hops #199/#204/#198) landed the cluster on 1.19.x — e2e-tested to k8s 1.35, one minor behind the cluster's 1.36. Closing that last minor needs Cilium 1.20 once it lists k8s 1.36 as tested."
  type        = string
  default     = "1.19.4"
}

variable "metrics_server_chart_version" {
  description = "metrics-server Helm chart version."
  type        = string
  default     = "3.13.0"
}

variable "local_path_version" {
  description = "Tag (with leading v) of rancher/local-path-provisioner whose deploy/local-path-storage.yaml is applied."
  type        = string
  default     = "v0.0.32"
}
