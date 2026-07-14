Prometheus deployed as deployment, without any storage configured:

```sh
k apply -f prometheus-deployment.yaml

k port-forward -n monitoring deployment/prometheus-deployment 9090:9090

# localhost
curl localhost:9090
<a href="/query">Found</a>.
```

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








[1] https://github.com/prometheus/prometheus/tree/release-3.13/tsdb
[2] https://prometheus.io/docs/prometheus/latest/storage/#operational-aspects
[3] https://hub.docker.com/layers/prom/prometheus/v3.13.1/images/sha256-bd2dcadfb0d1096e2a4c21817ac7af918e2f19ff628e4bf25fd67a924c13dd80
[4] https://github.com/prometheus/prometheus/blob/73ff57ce2b8161059ac7fe5188f03f1c3d22b29a/cmd/prometheus/main.go#L485
