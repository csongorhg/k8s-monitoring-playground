# Alertmanager

Why statefulset:

- store silences

```sh
# apply config map
k apply -f alertmanager-secret.yaml

# deploy prometheus
k apply -f alertmanager.yaml

# port-forward prometheus
k port-forward -n monitoring sts/alertmanager 9093:9093

# health check
# to check Alertmanager health
curl -X GET http://localhost:9093/-/healthy

# readiness check
# returns 200 when Alertmanager is ready to serve traffic
curl -X GET http://localhost:9093/-/ready

# inspect mounted config
k exec -it alertmanager-0 -n monitoring -- cat /etc/alertmanager/alertmanager.yml

# reload config
curl -X POST http://localhost:9093/-/reload
```
