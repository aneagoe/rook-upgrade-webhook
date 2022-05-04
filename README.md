# rook upgrade mitigation for [RBD lock-up](https://github.com/rook/rook/issues/8085#issuecomment-859234755).

This repository contains a very simple mutating webhook implementation written in Python. Its sole purpose is to modify pod resources in 
namespace `rook-ceph` which have a label of `app=csi-rbdplugin` or `app=csi-cephfsplugin` and add `hostNetwork: true`. This allows us to
do a rolling drain/delete of CSI pods to have a controlled and safe way of upgrading rook. 

## Usage

### 1. Build
Build and push to your registry:
```
docker build -t myawesomeregistry.example.com:5000/rook-upgrade:v0.1 .
docker push myawesomeregistry.example.com:5000/rook-upgrade:v0.1
```

### 2. Adjust manifests

Replace image in `manifests/deployment.yaml` with the registry/tag in step 1.
Adjust the MutatingWebhookConfiguration as required (eg if rook is deployed in a non-standard namespace).
Generate new certificates and apply manifests:
```
bash keys/gencerts.sh
kubectl apply -f manifests/namespace.yaml -f manifests/service.yaml -f manifests/certs.yaml -f manifests/deployment.yaml \
-f manifests/mutatingwebhook.yaml
```

For each node, cordon and then delete all the PODs using RBD or CEPHFS mounts. It can be easier to drain the entire node.
In order to test the behavior safely, simply drain one node then delete the CSI pods deployed on that node. The new ones
coming up should now be using the host network instead of pod network (see further down).

Before:
```
kubectl get pods -n rook-ceph -l 'app in (csi-rbdplugin,csi-cephfsplugin)' -o wide
NAME                     READY   STATUS    RESTARTS   AGE     IP              NODE                               NOMINATED NODE   READINESS GATES
csi-cephfsplugin-sxggf   3/3     Running   0          4d      10.14.2.9       worker-01.testcluster.example.com   <none>           <none>
csi-cephfsplugin-vd554   3/3     Running   0          4d      10.13.2.8       worker-02.testcluster.example.com   <none>           <none>
csi-rbdplugin-2lc6s      3/3     Running   0          4d      10.13.4.7       worker-01.testcluster.example.com   <none>           <none>
csi-rbdplugin-78kbj      3/3     Running   0          4d      10.15.0.5       worker-02.testcluster.example.com   <none>           <none>
```

After:
```
kubectl get pods -n rook-ceph -l 'app in (csi-rbdplugin,csi-cephfsplugin)' -o wide
NAME                     READY   STATUS    RESTARTS   AGE     IP              NODE                               NOMINATED NODE   READINESS GATES
csi-cephfsplugin-6m7mr   3/3     Running   0          3m      10.10.128.184   worker-01.testcluster.example.com   <none>           <none>
csi-cephfsplugin-9hmlb   3/3     Running   0          3m      10.10.128.185   worker-02.testcluster.example.com   <none>           <none>
csi-rbdplugin-gvtjd      3/3     Running   0          3m      10.10.128.184   worker-01.testcluster.example.com   <none>           <none>
csi-rbdplugin-ndn5r      3/3     Running   0          3m      10.10.128.185   worker-02.testcluster.example.com   <none>           <none>
```

Ensure that *all* CSI pods are using host network before proceeding!!!

### 3. Apply rook upgrade (to v1.7.11):
```
git clone --single-branch --depth=1 --branch v1.7.11 https://github.com/rook/rook.git
kubectl apply -f rook/cluster/examples/kubernetes/ceph/common.yaml -f rook/cluster/examples/kubernetes/ceph/crds.yaml -f \
rook/cluster/examples/kubernetes/ceph/monitoring/rbac.yaml
kubectl set image deployment/rook-ceph-operator rook-ceph-operator=rook/ceph:v1.7.11 -n rook-ceph
```

The CSI DaemonSet(s) will start to upgrade and eventually, all will be replaced with newer versions. At this point, it should
be safe to delete the MutatingWebhookConfiguration as well as the `rook-upgrade` namespace:
```
kubectl delete mutatingwebhookconfiguration rook-upgrade-webhook
kubectl delete ns rook-upgrade
```
