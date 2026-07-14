Requires Docker.

```sh
brew install kind
kind create cluster --config kind-config.yaml
k apply -f monitoring-namespace.yaml
```

Check cluster:

```sh
k get nodes
NAME                 STATUS   ROLES           AGE     VERSION
kind-control-plane   Ready    control-plane   5m10s   v1.36.1
kind-worker          Ready    <none>          5m      v1.36.1
kind-worker2         Ready    <none>          5m      v1.36.1

k get ns
NAME                 STATUS   AGE
default              Active   8m38s
kube-node-lease      Active   8m38s
kube-public          Active   8m38s
kube-system          Active   8m38s
local-path-storage   Active   8m34s
monitoring           Active   5m25s
```

Patch netskope on kind nodes:

```sh
./patch-netskope.sh /path/to/netskope-cert.crt kind-control-plane kind-worker kind-worker2
```
