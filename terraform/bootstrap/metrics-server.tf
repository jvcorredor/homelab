# metrics-server: the one always-on addon the barebones floor keeps.
# Provides `kubectl top` and resource metrics for the HPA/VPA APIs.
resource "kubernetes_namespace" "metrics_server" {
  metadata {
    name = "metrics-server"
  }
}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.metrics_server_chart_version
  namespace  = kubernetes_namespace.metrics_server.metadata[0].name

  # Talos issues kubelet serving certs from its own machine-CA, so
  # kubelet-insecure-tls is required; no node has an ExternalIP, so it is
  # dropped from the preferred address types.
  set {
    name  = "defaultArgs"
    value = "{--cert-dir=/tmp,--kubelet-insecure-tls,--kubelet-preferred-address-types=InternalIP\\,Hostname,--kubelet-use-node-status-port,--metric-resolution=15s}"
  }

  depends_on = [helm_release.cilium]
}
