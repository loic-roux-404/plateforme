# Help

### FAQ

I tried several times the vm provision with different configurations forcing me to apply / destroy the stack several times. However, now I can't access the url with a **dns error** ?

It is probably the dns cache that returns the ip entry of an old vm because the time to live has not yet expired. For that in chrome we must clean this cache to make as if we had never been on the site.
In your chrome browser [chrome://net-internals/#dns]() do a "clear host cache" and try again.

Also you can use a global flush cache if it still doesn't work:
 
- [for google dns](https://developers.google.com/speed/public-dns/cache?hl=fr)
- [for cloudflare dns](https://1.1.1.1/purge-cache/)

> For real world testing, it's best to use different `dex_hostname` and `waypoint_hostname` entries that you don't use for one environment (staging or production).

### Kubernetes on Vscode

To consolidate the debugging of our dev ops environment we can integrate our kubernetes cluster into the vscode IDE.

We will fetch the kubeconfig in our container that embeds K3s and the cluster.

Copy the kube config k3s with :

```sh
docker cp node-0:/etc/rancher/k3s/k3s.yaml ~/.kube/config
```

If you don't have kubectl locally:

- [For mac](https://kubernetes.io/docs/tasks/tools/install-kubectl-macos/)
- [For Wsl / Linux](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)

Then we check with `kubectl cluster-info` which should give us the information of the k3s node.

##### Then on `vscode` use these user parameters to see and use the cluster

> To show the path to home `cd ~ && pwd && cd -`

> [.vscode/settings.json](.vscode/settings.json)
```json
    "vs-kubernetes": {
        "vs-kubernetes.knownKubeconfigs": [
            "<path-to-home>/.kube/config"
        ],
        "vs-kubernetes.kubeconfig": [ "<Path-to-home>/.kube/config"
    }
```

And there you have access to an interface to control your cluster directly from vscode. Use this `json` configuration as much as you want in your application repositories to have a production-like experience.

## Sources

- [packer-kvm](https://github.com/goffinet/packer-kvm/blob/master/http/jammy/user-data)
- [coredns wildcard](https://mac-blog.org.ua/kubernetes-coredns-wildcard-ingress/)
