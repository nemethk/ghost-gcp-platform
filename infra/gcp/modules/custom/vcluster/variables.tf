variable "name" {
  description = "vCluster name (\"test\" or \"acceptance\") — also the Helm release name."
  type        = string
}

variable "namespace" {
  description = "Namespace on the host (nonprod) cluster to install into."
  type        = string
  default     = null
}

variable "chart_version" {
  description = "vcluster Helm chart version to pin."
  type        = string
}

variable "resources" {
  description = "Resource requests/limits for the vCluster control plane (Autopilot bills per-pod request, so keep these deliberate)."
  type = object({
    requests = optional(object({ cpu = optional(string, "250m"), memory = optional(string, "256Mi") }), {})
    limits   = optional(object({ cpu = optional(string, "1"), memory = optional(string, "1Gi") }), {})
  })
  default = {}
}
