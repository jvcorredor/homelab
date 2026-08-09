output "default_storage_class" {
  description = "Name of the StorageClass marked default after bootstrap."
  value       = "local-path"
}

output "lb_pool_range" {
  description = "Inclusive IP range allocated to LoadBalancer services by Cilium."
  value       = "${var.lb_pool_start}-${var.lb_pool_end}"
}
