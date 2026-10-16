# Monitoring Helm Chart

This chart installs a monitoring stack including:

- Prometheus
- Alertmanager
- Grafana (when an admin password is provided)
- kube-state-metrics
- node-exporter
- podinfo

## Install

The chart can be installed without a Grafana admin password; Grafana resources are
skipped until `grafana.adminPassword` is provided. To install or enable Grafana,
set the password:

```sh
read -r -s GRAFANA_ADMIN_PASSWORD
```

Then install or upgrade the chart:

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
