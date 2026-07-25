## Understand SC, PV, PVC and binding

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

[1] https://www.youtube.com/watch?v=0swOh5C3OVM
[2] https://www.youtube.com/watch?v=FAnQTgr04mU
[3] https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/#volume-claim-templates
