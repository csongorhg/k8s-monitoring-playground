Prometheus deployed as deployment, without any storage configured:

```sh
k apply -f prometheus-deployment.yaml

k port-forward -n monitoring deployment/prometheus-deployment 9090:9090

# localhost
curl localhost:9090
<a href="/query">Found</a>.
```
