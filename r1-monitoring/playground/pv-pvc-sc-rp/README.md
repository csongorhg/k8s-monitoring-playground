# Understand SC, PV, PVC and binding

Some notes from [1] and [2]:

Storage requirements:
  - Storage that doesn't depend on pod lifecycle, e.g. storage is not erased if the pod is deleted, new pod will pick it up.
  - Storage needs to be available on all nodes, since we don't know on which node the new pod would be created.
  - Storage needs HA if the cluster crashes

PV:
  - cluster resource
  - interface between the cluster and the acutal storage (NFS, local disk on the K8S node ...)

## Create PV and PVC

Note so far I didn't deploy the prometheus sts.

Deploying the PV:

```sh
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM                                        STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
prometheus-pv                              1Gi        RWO            Retain           Available                                                               <unset>                          3m11s
```

Deploying the PVC (no StorageClass specified):

```sh
k get pvc
NAME                              STATUS    VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
prometheus-pvc                    Pending                                                                        standard       <unset>                 18s
```

The PVC status is still Pending, which is expected due to:

```sh
Events:
  Type    Reason                Age                  From                         Message
  ----    ------                ----                 ----                         -------
  Normal  WaitForFirstConsumer  5s (x17 over 3m55s)  persistentvolume-controller  waiting for first consumer to be created before binding
```

## Attempt bindig the manually created PVC via volumeClamimTemplates

Let's try adding a label selector to the sts. First delete sts and the previously generated PVC.

The pod is stuck in Pending state, this is due to:
```sh
failed to provision volume with StorageClass "standard": claim.Spec.Selector is not supported
```

Let's try via pointing to the manually created PV via `volumeName: prometheus-pv`. Still fails with:
```sh
Cannot bind to requested volume "prometheus-pv": storageClassName does not match
```

I suppose this approach will not work, as `volumeClamimTemplates` always creates a PVC [3].

Note, in the PVC one has to set `StorageClassName: ""` to avoid the default storage class being used.

Now  after creating the sts, the manually created PVC is used by the prometheus pod.

```sh
k get pvc
NAME             STATUS   VOLUME          CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
prometheus-pvc   Bound    prometheus-pv   1Gi        RWO                           <unset>                 4m27s
k get pv
NAME            CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                       STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
prometheus-pv   1Gi        RWO            Retain           Bound    monitoring/prometheus-pvc                  <unset>                          85m
```

## Mitigate permission issue in prometheus

Mitigate err="open /prometheus/queries.active: permission denied" issue via initContainer [4].

The image defines `USER: nobody` [5] to run the container.

```sh
/ $ ls -lah | grep prometheus
drwxr-xrwx    4 root     root        4.0K Aug  3 20:04 prometheus
/ $ id
uid=65534(nobody) gid=65534(nobody) groups=65534(nobody)
/ $ ls -lah prometheus/
total 92K
drwxr-xrwx    4 root     root        4.0K Aug  3 20:04 .
drwxr-xr-x    1 root     root        4.0K Aug  3 20:03 ..
drwxr-xr-x    2 nobody   nobody      4.0K Aug  3 20:03 chunks_head
-rw-------    1 nobody   nobody    204.0K Aug  3 20:04 core
-rw-r--r--    1 nobody   nobody         0 Aug  3 20:03 lock
-rw-r--r--    1 nobody   nobody     19.5K Aug  3 20:03 queries.active
drwxr-xr-x    2 nobody   nobody      4.0K Aug  3 20:03 wal
```

## Access modes (RWO, ROX, RWX)

  - RWO: ReadWriteOnce - the volume can be mounted as read-write by a single node
  - ROX: ReadOnlyMany - the volume can be mounted read-only by many nodes
  - RWX: ReadWriteMany - the volume can be mounted as read-write by many nodes
  - RWOP: ReadWriteOncePod - same as RWO, but the volume can be mounted by a single pod

Local volume RWO, because the volume is local to the node, and hence the volume can be only mounted by a single node. [6]

## Storage class

Local volumes do not support dynamic provisioning in Kubernetes 1.36; however a StorageClass should still be created to delay volume binding until a Pod is actually scheduled to the appropriate node. This is specified by the WaitForFirstConsumer volume binding mode. Delaying volume binding allows the scheduler to consider all of a Pod's scheduling constraints when choosing an appropriate PersistentVolume for a PersistentVolumeClaim. [7]

Note: both the pv and the pvc needs to reference the same StorageClass.

Also `persistentVolumeReclaimPolicy: Delete` needs to be set in the PV.

When setting Delete reclaim policy, I get:

```sh
Warning  VolumeFailedDelete  12s   persistentvolume-controller  host_path deleter only supports /tmp/.+ but received provided /mnt/data
```

This is because I use `pv.spec.hostPath` in the PV. Thus `persistentVolumeReclaimPolicy` needs to be set to `Recycle`? [8]

```sh
Normal   VolumeRecycled      96s   persistentvolume-controller  Volume recycled
```

I suppose `hostPath` only supports mounts to `/tmp` and when that is set, then after deleting the STS and the PVC, the PV gets also deleted.

[1] https://www.youtube.com/watch?v=0swOh5C3OVM

[2] https://www.youtube.com/watch?v=FAnQTgr04mU

[3] https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/#volume-claim-templates

[4] https://github.com/prometheus/prometheus/issues/5976#issuecomment-1420961554

[5] https://hub.docker.com/layers/prom/prometheus/v3.13.1/images/sha256-bd2dcadfb0d1096e2a4c21817ac7af918e2f19ff628e4bf25fd67a924c13dd80

[6] https://kubernetes.io/docs/concepts/storage/persistent-volumes/#access-modes

[7] https://kubernetes.io/docs/concepts/storage/storage-classes/#local

[8] https://kubernetes.io/docs/concepts/storage/persistent-volumes/#reclaim-policy
