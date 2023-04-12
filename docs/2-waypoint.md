# Waypoint usage

## Setup waypoint

- [Install waypoint](https://developer.hashicorp.com/waypoint/downloads)

Setup waypoint inside cluster before getting token :

```bash
Run KUBECONFIG=/etc/rancher/k3s/k3s.yaml waypoint login -from-kubernetes"
```

Setup waypoint login context outside cluster :

> You can use `waypoint.k3s.test:443` in a simple network network (VPN, Firewall, DnsMasq are probably going to gives you trouble)

```bash
export WAYPOINT_SERVER_TOKEN=token
waypoint context create \
    -server-addr='localhost:32701' \
    -server-auth-token="$WAYPOINT_SERVER_TOKEN" \
    -server-require-auth=true \
    -server-tls-skip-verify=true \
    -set-default waypoint.k3s.test-ui

```

## Create git ops waypoint project

```bash
waypoint init
```

> Only `waypoint init` will not configure git repo for you. You need to use customised `waypoint project apply` to do it.

Using ssh :

```bash
waypoint project apply \
   -data-source=git \
   -git-auth-type=ssh \
   -git-private-key-path=$HOME/.ssh/id_rsa \
   -git-url=git@github.com:hashicorp/waypoint-examples.git \
   example-project
```

Using password :

```bash
waypoint project apply \
   -data-source=git \
   -git-auth-type=basic \
    -git-username=<string> \
    -git-password=<string> \
   -git-url=https://github.com:hashicorp/waypoint-examples.git \
   example-project
```


### Setup waypoint hcl

Adapted example from Hashicorp

```hcl
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

project = "kubernetes-go-multiapp-k8s-ingress"

variable "namespace" {
  default     = "default"
  type        = string
  description = "The namespace to deploy and release to in your Kubernetes cluster."
}

variable "registery_user" {
  type    = string
  description = "Username to login to container registry"
}

variable "registery_token" {
  type    = string
  description = "Token to login to container registry"
}

variable "k8s_ingress_annotations" {
  type    = map(string)
  description = "Kubernetes annotation to make ingress working"
  default  = {
    "nginx.ingress.kubernetes.io/rewrite-target" = "/"
    "kubernetes.io/ingress.class" = "nginx"
  }
}

variable "k8s_ingress_domain" {
  type    = string
  description = "Kubernetes domain to use"
  default  = "waypoint.k3s.test"
}


app "default-app" {
  labels = {
    "service" = "default-app",
    "env"     = "dev"
  }

  env {
    TEST_VAR = "0"
  }

  build {
    use "pack" {}
    registry {
      use "docker" {
        image = "loicroux/default-app"
        tag   = "1"
        local = false
        password = var.registery_token
        username = var.registery_user
      }
    }
  }

  deploy {
    use "kubernetes" {
      probe_path = "/"
      namespace  = var.namespace
    }
  }

  release {
    use "kubernetes" {
      namespace = var.namespace

      ingress "http" {
        default   = true
        path_type = "Prefix"
        path      = "/"
        host = "go-multiapp.${var.k8s_ingress_domain}"
        annotations = var.k8s_ingress_annotations
        tls {
            hosts = ["go-multiapp.${var.k8s_ingress_domain}"]
            secret_name = "go-multiapp.${var.k8s_ingress_domain}-tls"
        }
      }
    }
  }
}

```
