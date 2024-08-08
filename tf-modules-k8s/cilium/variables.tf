variable "cilium_version" {
  description = "The version of Cilium to deploy"
  type        = string
  default     = "1.16.0"
}

variable "k3s_host" {
  type = string
}

variable "node_name" {
  type = string
}

variable "k3s_port" {
  default = "6443"
}

variable "cilium_namespace" {
  default = "kube-system"
}

variable "cilium_helm_values" {
  type = object({
    global = optional(object({
      containerRuntime = object({
        integration = string
        socketPath  = string
      })
      kubeProxyReplacement = string
      bpf = object({
        masquerade = bool
      })
    }))
    kubeProxyReplacement = bool
    routingMode = string
    tunnelProtocol = string
    bpf = object({
      masquerade = bool
      lbExternalClusterIP = bool
    })
    ipam = optional(object({
      mode = string
    }))
    k8s = object({
      requireIPv4PodCIDR = bool
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
    l2announcements = object({
      enabled = bool 
    })
    clustermesh = object({
      useAPIServer = bool
    })
    prometheus = object({
      enabled = bool
      serviceMonitor = object({
        enabled = bool
      })
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
    l2announcements = {
      enabled = true
    }
    k8s = {
      requireIPv4PodCIDR = false
    }
    clustermesh = {
      useAPIServer = false
    }
    kubeProxyReplacement = true
    bpf = {
      masquerade = true
      lbExternalClusterIP = false
    }
    gatewayAPI = {
      enabled = false
    }
    routingMode = "tunnel"
    tunnelProtocol = "vxlan"
    ingressController = {
      enabled          = true
      default          = true
      loadbalancerMode = "dedicated"
    }
    prometheus = {
      enabled = true
      serviceMonitor = {
        enabled = true
      }
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


variable "external_blocks" {
  description = "List of block ranges for external IP pool."
  type        = list(map(string))
  default = []
}

variable "internal_blocks" {
  description = "List of block ranges for internal IP pool."
  type        = list(map(string))
  default = []
}
