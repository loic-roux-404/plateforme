variable "cilium_version" {
  description = "The version of Cilium to deploy"
  type        = string
  default     = "1.16.0"
}

variable "node_name" {
  default = "localhost"
}

variable "k3s_port" {
  default = "6443"
}

variable "cilium_namespace" {
  default = "cilium"
}

variable "cilium_helm_values" {
  type = object({
    global = object({
      containerRuntime = object({
        integration = string
        socketPath  = string
      })
      kubeProxyReplacement = string
      bpf = object({
        masquerade = bool
      })
    })
    kubeProxyReplacement = bool
    bpf = object({
      masquerade = bool
    })
    ipam = object({
      mode = string
    })
    endpointRoutes = optional(object({
      enabled = bool
    }))
    ingressController = object({
      enabled          = bool
      default          = bool
      loadbalancerMode = string
    })
    gatewayAPI = object({
      enabled = bool
      secretsNamespace = optional(object({
        sync = bool
      }))
    })
    prometheus = object({
      enabled = bool
    })
    operator = optional(object({
      replicas = number
      prometheus = object({
        enabled = bool
      })
    }))
    hubble = object({
      relay = object({
        enabled = bool
      })
      metrics = optional(object({
        enabled           = list(string)
        enableOpenMetrics = bool
      }))
    })
  })
  default = {
    global = {
      containerRuntime = {
        integration = "containerd"
        socketPath  = "/var/run/k3s/containerd/containerd.sock"
      }
      kubeProxyReplacement = "strict"
      bpf = {
        masquerade = true
      }
    }
    endpointRoutes = {
      enabled = true
    }
    ipam = {
      mode = "kubernetes"
    }
    kubeProxyReplacement = true
    bpf = {
      masquerade = true
    }
    gatewayAPI = {
      enabled = false
    }
    ingressController = {
      enabled          = true
      default          = true
      loadbalancerMode = "shared"
    }
    prometheus = {
      enabled = true
    }
    operator = {
      replicas = 1
      prometheus = {
        enabled = true
      }
    }
    hubble = {
      relay = {
        enabled = true
      }
      metrics = {
        enabled = [
          "dns", "drop", "tcp", "flow", "port-distribution", "icmp",
          "httpV2:exemplars=true;labelsContext=source_ip,source_namespace,source_workload,destination_ip,destination_namespace,destination_workload,traffic_direction"
        ]
        enableOpenMetrics = true
      }
    }
  }
}
