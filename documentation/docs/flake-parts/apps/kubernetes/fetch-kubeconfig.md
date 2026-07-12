# fetch-kubeconfig

Fetch a remote kubeconfig from a k3s or rke2 node.

```console
$ nix run ".#fetch-kubeconfig" <remote> <cluster-name> [k3s|rke2]
```

- `<remote>`: IP address or hostname of the remote node (will connect as `root@<remote>`)
- `<cluster-name>`: Name to use for the cluster context and kubeconfig file
- `[k3s|rke2]`: Cluster type (`k3s` by default)

**Examples:**

```console
# k3s (default)
$ nix run ".#fetch-kubeconfig" 95.216.11.88 hcloud

# rke2
$ nix run ".#fetch-kubeconfig" 95.216.11.88 hcloud rke2
```

- `<remote>`: IP address or hostname of the remote node (will connect as `root@<remote>`)
- `<cluster-name>`: Name to use for the cluster context and kubeconfig file
- `[k3s|rke2]`: Cluster type (`k3s` by default)

**Examples:**

```console
# k3s (default)
$ nix run ".#fetch-kubeconfig" 95.216.11.88 hcloud

# rke2
$ nix run ".#fetch-kubeconfig" 95.216.11.88 hcloud rke2
```