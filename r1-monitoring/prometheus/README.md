# Prometheus

Why statefulset:

- Prometheus time series database is stored in local storage
- persist database across pod restarts

```sh
# apply config map
k apply -f prometheus-configmap.yaml

# deploy prometheus
k apply -f prometheus.yaml

# port-forward prometheus
k port-forward -n monitoring sts/prometheus 9090:9090

# show metrics
curl localhost:9090/metrics

# inspect mounted config
k exec -it prometheus-0 -n monitoring -- cat /etc/prometheus/prometheus.yml

# open shell in pod
k exec -it prometheus-0 -n monitoring -- /bin/sh

# show active targets
curl -s 'http://localhost:9090/api/v1/targets' | jq

# show dropped targets
curl -s 'http://localhost:9090/api/v1/targets?state=dropped' | jq

# show rendered config
curl -s http://localhost:9090/api/v1/status/config | jq -r '.data.yaml' | yq -P

# reload config after ConfigMap edit
# requires --web.enable-lifecycle
curl -X POST http://localhost:9090/-/reload
```
