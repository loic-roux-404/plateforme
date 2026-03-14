# Install PaaS for debug on a single machine

---

This PaaS solution targets a contabo VPS or a local machine with libvirt. This one will be based on [kubernetes](https://kubernetes.io/fr/) for the containerization and [dex](https://dexidp.io/https://dexidp.io/) for the k8S accesses and an oauth proxy for hosted web apps.

The optics of this tooling will follow :

- The principle **of immutable infrastructure** with the idea of recreating rather than updating. Thus we will use ready linux iso to deploy the **kubernetes** / **waypoint** platform directly on a server.

- The principle **infrastructure as code** (IaC) by keeping all the specification of our infrastructure in configurations and scripts. We will also use basic tests of our configurations.

For this we will use a technical base composed of :

- [`rke2`](https://docs.rke2.io/) A Kubernetes distribution built for production workloads. It is a CNCF-certified Kubernetes distribution that provides a simple and easy-to-use installation process, as well as a number of features that make it well-suited for production environments.
- [Nix Os](https://nixos.org/manual/nixpkgs/stable/) to create iso images of linux machines
- [Terraform](https://www.terraform.io/) to control many cloud platforms like Gandi, Contabo, GitHub, kubernetes...

> Note : Here we are only using single node mode

## Secure ssh connections

After applying infrastructure to terraform you will be able to log in ssh with :

```bash
ssh user@device-name
```

