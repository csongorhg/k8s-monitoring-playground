## Prometheus deployment without storage

Prometheus deployed as deployment, without any storage configured:

```sh
k apply -f prometheus-deployment.yaml

k port-forward -n monitoring deployment/prometheus-deployment 9090:9090

# localhost
curl localhost:9090
<a href="/query">Found</a>.
```

## TSDB ops

TSDB = Time Series Database:
 - handle storage and querying of all Prometheus v2 data [1]
 - `--storage.tsdb.path` where Prometheus writes its database, defaults to `data/` [2]

Checking prometheus container in the pod:
```sh
/prometheus $ pwd
/prometheus
/prometheus $ ls -lah
total 96K
drwxrwxr-x    4 nobody   nobody      4.0K Jul 14 18:07 .
drwxr-xr-x    1 root     root        4.0K Jul 14 17:24 ..
drwxr-xr-x    2 nobody   nobody      4.0K Jul 14 18:07 chunks_head
-rw-------    1 nobody   nobody    208.0K Jul 14 18:07 core
-rw-r--r--    1 nobody   nobody         0 Jul 14 17:24 lock
-rw-r--r--    1 nobody   nobody     19.5K Jul 14 17:39 queries.active
drwxr-xr-x    2 nobody   nobody      4.0K Jul 14 18:08 wal
```

Not sure why no `data/` dir in prom/prometheus:v3.13.1

Edit: last Docker layer seems to set `--storage.tsdb.path=/prometheus` [3]
and `main.go` indeed defaults to `data/` [4]

## Prometheus deployment with storage (attempt)

```sh
k apply -f prometheus-deployment-storage.yaml
Error from server (BadRequest): error when creating "prometheus-deployment-storage.yaml": Deployment in version "v1" cannot be handled as a Deployment: strict decoding error: unknown field "spec.template.volumeClaimTemplates"
```



## Kind local-path storage class

```sh
k get storageclass
NAME                 PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
standard (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  84m
```

Seems to be set as default storage class [5]. This storage class is present in all namespaces.

## Prometheus statefulset with storage
```sh
k get sts
NAME                     READY   AGE
prometheus-statefulset   1/1     27s

k get pvc
NAME                                          STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
prometheus-storage-prometheus-statefulset-0   Bound    pvc-1b5d8a97-1daa-47e3-b544-c4b698cbc714   1Gi        RWO            standard       <unset>                 21s

k get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                                                    STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
pvc-1b5d8a97-1daa-47e3-b544-c4b698cbc714   1Gi        RWO            Delete           Bound    monitoring/prometheus-storage-prometheus-statefulset-0   standard       <unset>                          29s
```

Prometheus statefulset w/o setting storageclass in volumeClaimTemplates seems to provision the volume.

## Prometheus ConfigMap

`config-files/prometheus.yml` is taken from [6]. First create ConfigMap, then mount the read-only file.

Note: `prometheus.yml` has to be defined in the ConfigMap and it can not be referenced from another dir.

Checking mounted file in pod:
```sh
/prometheus/config/config-files $ pwd prometheus.yml
/prometheus/config/config-files
```

However something seems odd with the symlinks:
```sh
/prometheus/config $ ls -lah
total 12K
drwxrwxrwx    3 root     root        4.0K Jul 21 20:16 .
drwxrwxrwx   17 root     root        4.0K Jul 21 20:16 ..
drwxr-xr-x    3 root     root        4.0K Jul 21 20:16 ..2026_07_21_20_16_17.846450547
lrwxrwxrwx    1 root     root          31 Jul 21 20:16 ..data -> ..2026_07_21_20_16_17.846450547
lrwxrwxrwx    1 root     root          19 Jul 21 20:16 config-files -> ..data/config-files
```

The image sets ENTRYPOINT:
```sh
ENTRYPOINT ["/bin/prometheus"]
```

and the following CMD:
```sh
CMD ["--config.file=/etc/prometheus/prometheus.yml" "--storage.tsdb.path=/prometheus"]
```

FYI differences between `ENTRYPOINT`, `CMD` and `RUN` in Docker [7], related topics in K8S [8].

We shall alter `command` and `args` to reflect the mounted `prometheus.yml` in case the image changes upstream.

Seems to work now as expected:
```sh
/etc/prometheus $ realpath prometheus.yml
/etc/prometheus/..2026_07_22_20_03_37.823969328/prometheus.yml
/etc/prometheus $ head prometheus.yml
# source: https://github.com/prometheus/prometheus/blob/main/documentation/examples/prometheus.yml
# my global config
global:
  scrape_interval: 15s # Set the scrape interval to every 15 seconds. Default is every 1 minute.
  evaluation_interval: 15s # Evaluate rules every 15 seconds. The default is every 1 minute.
  # scrape_timeout is set to the global default (10s).

# Alertmanager configuration
alerting:
  alertmanagers:
```

[1] https://github.com/prometheus/prometheus/tree/release-3.13/tsdb

[2] https://prometheus.io/docs/prometheus/latest/storage/#operational-aspects

[3] https://hub.docker.com/layers/prom/prometheus/v3.13.1/images/sha256-bd2dcadfb0d1096e2a4c21817ac7af918e2f19ff628e4bf25fd67a924c13dd80

[4] https://github.com/prometheus/prometheus/blob/73ff57ce2b8161059ac7fe5188f03f1c3d22b29a/cmd/prometheus/main.go#L485

[5] https://github.com/kubernetes-sigs/kind/blob/cda67ef8588f6bfdac5358233f2471cb2149ecaf/pkg/cluster/internal/create/actions/installstorage/storage.go#L77

[6] https://github.com/prometheus/prometheus/blob/main/documentation/examples/prometheus.yml

[7] https://www.docker.com/blog/docker-best-practices-choosing-between-run-cmd-and-entrypoint/

[8] https://kubernetes.io/docs/tasks/inject-data-application/define-command-argument-container/
