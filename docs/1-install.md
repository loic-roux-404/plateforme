# Install PaaS for debug on a single machine

---

This PaaS solution targets small machine or on personal server. This one will be based on [kubernetes](https://kubernetes.io/fr/) for the containerization and [waypoint](https://developer.hashicorp.com/waypoint) for the deployment interface and automations.

The optics of this tooling will follow :

- tThe principle **of immutable infrastructure** with the idea of recreating rather than updating. Thus we will use ready linux iso to deploy the **kubernetes** / **waypoint** platform directly on a server.

- The principle **infrastructure as code** (IaC) by keeping all the specification of our infrastructure in configurations and scripts. We will also use basic tests of our configurations.

For this we will use a technical base composed of :

- [`k3s`](https://k3s.io/) tool which simplifies the installation of kubernetes on ARM machines while remaining compatible with classic X64 architectures. It provides by default pods (containers in execution) to include features often sought on this type of edge computing configuration (reverse proxy, DNS configuration ...)
- [Nix Os](https://nixos.org/manual/nixpkgs/stable/) to create iso images of linux machines
- [Terraform](https://www.terraform.io/) to control many cloud platforms like Gandi, Contabo, GitHub, kubernetes...

## Usefull links

Docker architecture :

![docker architecture](https://docs.docker.com/engine/images/architecture.svg)

K3s Architecture :

![docker k8s architecture](https://docs.k3s.io/assets/images/how-it-works-k3s-revised-9c025ef482404bca2e53a89a0ba7a3c5.svg)

> Note : Here we are only using single node mode

## Usage

To open UI with https add pebble certificate to your truststore (this is automaticly done by nixos-darwin):

```bash
curl -k https://localhost:15000/intermediates/0 > ~/Downloads/pebble-ca.pem
sudo security add-trusted-cert -d -r trustAsRoot -k /Library/Keychains/System.keychain ~/Downloads/pebble-ca.pem
```

## K3s PaaS

- [Dex](https://dex.k3s.test/.well-known/openid-configuration)
- [waypoint](https://waypoint.k3s.test/)

> Authentication with dex is not working over waypoint UI in localhost because of non-trusted certificate.

Setup waypoint inside cluster before getting token :

```bash
Run KUBECONFIG=/etc/rancher/k3s/k3s.yaml waypoint login -from-kubernetes
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

## Secure ssh connections

After applying infrastructure to terraform you will be able to log in ssh with :

```bash
ssh user@device-name
```

## Create git ops waypoint project

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
