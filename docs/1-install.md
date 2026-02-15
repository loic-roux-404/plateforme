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
- Terraform

## Secure ssh connections

After applying infrastructure to terraform you will be able to log in ssh with :

```bash
ssh user@device-name
```

