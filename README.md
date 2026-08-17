# k8s-monitoring-playground

## Prerequisites

- `pre-commit`
- `kubeconform`
- `markdownlint-cli2`

## Setup

`pre-commit install --install-hooks`

See `setup-env/` for Kind setup and required dependencies.

## (Optional) Setup kappa (kubectl-apply-all)

The script applies the manifests in the current dir by prefix and `.yaml`
file extension matching.

alias kappa="kappa.sh"

## R1 questions

This pharagraph takes the questions from the R1 exercise.

### Component and workload type reasoning

| Component | Workload | Reason |
| --- | --- | --- |
| Prometheus | StatefulSet | Store TSDB data between restarts |
| Alertmanager | StatefulSet | Store silences between restarts |
| Grafana | Deployment | Config is provisioned from the repo |
| kube-state-metrics | Deployment | Stateless |
| node-exporter | DaemonSet | For each node 1 pod required, stateless |
| podinfo | Deployment | Stateless |

### ConfigMap and Secret

What is the difference between ConfigMap and Secret?

When to use which?

What is the difference between volume and env mount?

### Storage reclaim policies and volume access modes

Which policy and when to use in production and why?

Retain

Delete

Recycle

RWO

ROX

RWX

RWOP

## R1 Definition of Done

This pharagraph lists the DoD proofs and steps of demonstration.

### Pre-requisites

These steps were performed before checking against the DoDs:

- Kind cluster is running as stated in `setup-env/`
- `monitoring` namespace is created
- All component manifests in `r1-monitoring/` are applied
- Port-forwarding is set up for Grafana and Prometheus like:

```sh
kubectl port-forward --namespace monitoring svc/grafana-service 3000:3000
kubectl port-forward --namespace monitoring svc/prometheus-service 9090:9090
```

### DoD

For consistency reasons, the DoD was translated to English.

Definition of done:

- [x] Every Prometheus target is up == 1

  ```sh
  curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {
    endpoint: .scrapeUrl,
    labels: .labels,
    lastScrape: .lastScrape,
    health: .health
  }'
  ```

  Output:

  ```text
  {
    "endpoint": "http://10.244.1.16:8080/metrics",
    "labels": {
      "instance": "10.244.1.16:8080",
      "job": "kube-state-metrics"
    },
    "lastScrape": "2026-08-17T14:49:50.518603168Z",
    "health": "up"
  }
  {
    "endpoint": "http://10.244.3.48:9100/metrics",
    "labels": {
      "instance": "10.244.3.48:9100",
      "job": "node-exporter"
    },
    "lastScrape": "2026-08-17T14:49:48.596586292Z",
    "health": "up"
  }
  {
    "endpoint": "http://10.244.1.23:9100/metrics",
    "labels": {
      "instance": "10.244.1.23:9100",
      "job": "node-exporter"
    },
    "lastScrape": "2026-08-17T14:49:40.759009677Z",
    "health": "up"
  }
  {
    "endpoint": "http://10.244.3.18:9898/metrics",
    "labels": {
      "instance": "10.244.3.18:9898",
      "job": "podinfo"
    },
    "lastScrape": "2026-08-17T14:49:40.562475969Z",
    "health": "up"
  }
  {
    "endpoint": "http://localhost:9090/metrics",
    "labels": {
      "instance": "localhost:9090",
      "job": "prometheus"
    },
    "lastScrape": "2026-08-17T14:49:41.615578886Z",
    "health": "up"
  }
  ```

<!-- markdownlint-disable-next-line MD013 -->
- [x] Data persists after deleting the Prometheus pod (PVC + StatefulSet purpose); no state is lost after deleting the Grafana pod (Deployment + provisioning purpose)

  Prometheus:
  
  ```sh
  kubectl scale sts/prometheus -n monitoring --replicas=0
  # Wait to demonstrate that we don't store scraped metrics till
  # the prometheus pod is scaled up again. (scrape_interval: 15s)
  kubectl scale sts/prometheus -n monitoring --replicas=1
  kubectl port-forward --namespace monitoring svc/prometheus-service 9090:9090
  ```

  The new pod got attached to the existing PVC:

  ```sh
  kubectl get pod -n monitoring | grep prometheus
  prometheus-0                          1/1     Running   0          15m
  # Check the age of the PVC
  kubectl get pvc | grep prometheus
  prometheus-storage-prometheus-0       Bound    pvc-e3970d2e-fcce-4843-8bbc-2c4f1090b4fd   1Gi        RWO            standard       <unset>                 6d9h
  # Check the existing PVC got bound to the new pod
  kubectl describe pvc prometheus-storage-prometheus-0 | grep "Used By"
  Used By:       prometheus-0
  ```

  The `prometheus_target_scrape_pool_targets{scrape_job="node-exporter"}`
  metrics are present after scaling up the Prometheus StatefulSet.
  ![Prometheus metric state was restored after scale-up](screenshots/prom_metric_after_scaleup.png)

  Grafana:

  ```sh
  kubectl scale deploy/grafana -n monitoring --replicas=0
  kubectl scale deploy/grafana -n monitoring --replicas=1
  kubectl port-forward --namespace monitoring svc/grafana-service 3000:3000
  ```

  The dashboards persisted in the ConfigMap are present after scaling up.
  ![Grafana dashboard state was restored after scale-up](screenshots/grafana_dashboards_after_scaleup.png)

<!-- markdownlint-disable-next-line MD013 -->
- [x] node-exporter runs on both workers, but not necessarily on the control plane (DaemonSet + tolerations/scheduling)

  As expected, the node-exporter DaemonSet scheduled exactly one node-exporter
  pod to each worker node.

  ```sh
  kubectl get pods -o wide -n monitoring | grep node-exporter
  node-exporter-d9btx                   1/1     Running   0          6h55m   10.244.3.48   kind-worker    <none>           <none>
  node-exporter-nq9px                   1/1     Running   0          6h55m   10.244.1.23   kind-worker2   <none>           <none>

  kubectl get nodes
  NAME                 STATUS   ROLES           AGE   VERSION
  kind-control-plane   Ready    control-plane   13d   v1.36.1
  kind-worker          Ready    <none>          13d   v1.36.1
  kind-worker2         Ready    <none>          13d   v1.36.1
  ```

  No node-exporter pod got scheduled on the control-plane, because it is
  tainted.

  ```sh
  kubectl describe node kind-control-plane | grep Taints
  Taints:             node-role.kubernetes.io/control-plane:NoSchedule
  ```

<!-- markdownlint-disable-next-line MD013 -->
- [x] Prometheus/Alertmanager PVCs use dynamically provisioned PVs; kubectl get pv,pvc shows Bound status and the complete StorageClass -> PV -> PVC chain

  ```sh
  kubectl get pvc,pv
  NAME                                                        STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
  persistentvolumeclaim/alertmanager-storage-alertmanager-0   Bound    pvc-fa6971a8-a58c-4d71-afaa-4efcb069b93b   1Gi        RWO            standard       <unset>                 7d23h
  persistentvolumeclaim/prometheus-storage-prometheus-0       Bound    pvc-e3970d2e-fcce-4843-8bbc-2c4f1090b4fd   1Gi        RWO            standard       <unset>                 6d10h

  NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                                            STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
  persistentvolume/pvc-e3970d2e-fcce-4843-8bbc-2c4f1090b4fd   1Gi        RWO            Delete           Bound    monitoring/prometheus-storage-prometheus-0       standard       <unset>                          6d10h
  persistentvolume/pvc-fa6971a8-a58c-4d71-afaa-4efcb069b93b   1Gi        RWO            Delete           Bound    monitoring/alertmanager-storage-alertmanager-0   standard       <unset>                          7d23h
  ```

<!-- markdownlint-disable-next-line MD013 -->
- [ ] A manually created PV + PVC is bound without a StorageClass (Bound), demonstrating understanding of access modes

<!-- markdownlint-disable-next-line MD013 -->
- [ ] A custom StorageClass uses reclaimPolicy: Retain; after deleting the PVC, the PV is Released and the data remains; the difference compared with Delete is documented

<!-- markdownlint-disable-next-line MD013 -->
- [x] prometheus.yml is mounted as a ConfigMap volume; alertmanager.yml is mounted as a Secret volume; the Grafana admin password is provided as a Secret environment variable; the datasource and dashboard come from ConfigMaps, and the node dashboard works

  This was demonstrated in the previous steps, where the Prometheus Statefulset
  and Grafana Deployment after scaling up had the same config and dashboards.
  The config files, password and dashboards were consumed as stated by the DoD.

- [x] kube_* metrics can be queried through kube-state-metrics

  In Prometheus 108 kube_* metrics are present.

  ```sh
  curl -sG http://localhost:9090/api/v1/query \
  --data-urlencode 'query=count by (__name__) ({__name__=~"kube_.*"})' \
  | jq '.data.result[].metric.__name__' | wc -l
     108
  ```

  Note, that depending on the scraped metrics, it requires list, watch on
  K8S resources. Since there was no specification on which resources to scrape,
  I configured only a set of resources. This is why there are errors emitted by
  the kube-state-metrics pod like:

  ```text
  Failed to watch" err="failed to list *v1.PodDisruptionBudget: poddisruptionbudgets.policy is forbidden: User \"system:serviceaccount:monitoring:kube-state-metrics-sa\" cannot list resource 
  \"poddisruptionbudgets\" in API group \"policy\" at the cluster scope
  ```

<!-- markdownlint-disable-next-line MD013 -->
- [x] podinfo is scraped as an application target, with a custom PromQL panel for its custom metrics

  See previoulsy proof of scraping podinfo and persisting dashboards between
  restarts.
  
  ![podinfo metrics shown on a custom panel](screenshots/podinfo_promql_panel.png)

- [x] One alert rule reaches the firing state in the Alertmanager UI

  ```sh
  # trigger the alert 
  kubectl delete daemonset/node-exporter -n monitoring
  kubectl port-forward --namespace monitoring svc/alertmanager-service 9093:9093
  ```

  ![Alertmanager UI shows the alert firing](screenshots/alertmanager_alert_fires.png)

<!-- markdownlint-disable-next-line MD013 -->
- [x] The transition from static_configs to kubernetes_sd_configs is complete, including RBAC; new targets appear automatically

  ```sh
  # By default 1 podinfo target is scraped.
  curl -s http://localhost:9090/api/v1/targets \
  | jq '[.data.activeTargets[] | select(.labels.job == "podinfo")] | length'
  1
  # Scale podinfo deployment to 3 replicas
  kubectl scale deployment/podinfo --replicas=3 -n monitoring
  # After scaling, the targets are automatically discovered and scraped by Prometheus
  curl -s http://localhost:9090/api/v1/targets \
  | jq '[.data.activeTargets[] | select(.labels.job == "podinfo")] | length'
  3
  ´´´

- [x] prometheus.yml can be successfully reloaded manually after a ConfigMap change

  ```sh
  kubectl port-forward -n monitoring svc/prometheus-service 9090:9090

  # Take current scrape_interval as reference
  curl -s http://localhost:9090/api/v1/status/config \
  | jq -r '.data.yaml' \
  | grep -A1 '^global:'
  global:
    scrape_interval: 15s

  # Change the scrape interval to 30s
  kubectl edit configmap prometheus-config -n monitoring

  # Reload the config
  curl -X POST http://localhost:9090/-/reload

  # Check the new scrape interval is applied
    curl -s http://localhost:9090/api/v1/status/config \
  | jq -r '.data.yaml' \
  | grep -A1 '^global:'
  global:
    scrape_interval: 30s
  ```
