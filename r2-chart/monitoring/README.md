# Monitoring Helm Chart

This chart installs a monitoring stack including:

- Prometheus
- Alertmanager
- Grafana
- kube-state-metrics
- node-exporter
- podinfo

## Install

Make sure to set the Grafana admin password before installing the chart:

```sh
read -r -s GRAFANA_ADMIN_PASSWORD
```

and then install the chart like:

```sh
helm upgrade --install monitoring . \
  --namespace monitoring \
  --create-namespace \
  --set grafana.adminPassword="$GRAFANA_ADMIN_PASSWORD"
```

## Uninstall

```sh
helm uninstall monitoring
```
