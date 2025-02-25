---
title: "Running a Docker registry on Kubernetes (in kind)"
date: "2020-11-06"
people: 
- Max Jonas Werner
cover:
  image: "/images/library.jpg"
---

In the last weeks I have been working a lot on supporting Kubernetes in air-gapped environments, i.e. environments that don't have any access to the internet. Many companies prefer to run their IT infrastructure in such a way to minimize the attack vector against it and be able to tightly control what's running on their clusters. Part of these setups naturally is a Docker registry that runs on that air-gapped infrastructure and in order to properly reproduce such a scenario, I had to run a Docker registry on my [kind](https://kind.sigs.k8s.io/) cluster as well and I thought sharing the manifests may help anyone out there get setup faster next time. Running a Docker registry may be even more important given the [new position](https://www.docker.com/blog/what-you-need-to-know-about-upcoming-docker-hub-rate-limiting/) that Docker Inc. has put us into.

## TL;DR ⏳

When trying to run a custom Docker registry on kind, you will face some obstacles: The registry has to be reachable from outside of the cluster (to push images) and from each cluster node (by kubelet). Plus, the CA certificate of the registry has to be advertised to each cluster node as well. [Jump down for the TL;DR steps](#the-complete-rundown-).

## Getting there 🚶

My first idea was to just create a `Secret`, a `Deployment` and a `ClusterIP` `Service` exposing the deployment. To be able to push images to the running registry I just had to add `registry.registry.svc` to my `/etc/hosts` file with the address 127.0.0.1 and do a `kubectl -n registry port-forward svc/registry 1443`. From then on I was able to tag an image with the `registry.registry:1443/` prefix and push it to the newly created registry. 🥳

```sh
$ docker tag nginx:1.19.4 registry.registry.svc:1443/nginx:1.19.4
$ docker push registry.registry.svc:1443/nginx:1.19.4
The push refers to repository [registry.registry.svc:1443/nginx]
7b5417cae114: Layer already exists
aee208b6ccfb: Layer already exists
2f57e21e4365: Layer already exists
2baf69a23d7a: Pushed
d0fe97fa8b8c: Pushed
1.19.4: digest: sha256:34f3f875e745861ff8a37552ed7eb4b673544d2c56c7cc58f9a9bec5b4b3530e size: 1362
$ k run nginx --image=registry.registry.svc:1443/nginx:1.19.4
pod/nginx created
$ k get pod nginx
NAME    READY   STATUS         RESTARTS   AGE
nginx   0/1     ErrImagePull   0          13s
```

Whoops, that didn't work so well. So a pod that would reference the image I just pushed into the internal registry has issues pulling it. Let's look at the details:

```sh
$ k describe pod nginx
[...]
Events:
  Type     Reason     Age               From               Message
  ----     ------     ----              ----               -------
  Normal   Scheduled  16s               default-scheduler  Successfully assigned default/nginx to kind-control-plane
  Normal   BackOff    15s               kubelet            Back-off pulling image "registry.registry.svc:1443/nginx:1.19.4"
  Warning  Failed     15s               kubelet            Error: ImagePullBackOff
  Normal   Pulling    3s (x2 over 16s)  kubelet            Pulling image "registry.registry.svc:1443/nginx:1.19.4"
  Warning  Failed     3s (x2 over 16s)  kubelet            Failed to pull image "registry.registry.svc:1443/nginx:1.19.4": rpc error: code = Unknown desc = failed to pull and unpack image "registry.registry.svc:1443/nginx:1.19.4": failed to resolve reference "registry.registry.svc:1443/nginx:1.19.4": failed to do request: Head https://registry.registry.svc:1443/v2/nginx/manifests/1.19.4: dial tcp 127.0.0.1:1443: connect: connection refused
  Warning  Failed     3s (x2 over 16s)  kubelet            Error: ErrImagePull
```

Look closely at the `From` column of the events. It's the kubelet service that's unable to pull the image and when you think about it, it makes total sense that it can't because kubelet isn't run inside of the cluster but rather directly on each node. So somehow I needed to make the registry available to each node.

## Trying Harder 💪

Enter the `NodePort` service type which makes a service available externally via the IP addresses of cluster nodes. This service also helps us killing two birds with one stone: We can push images to the registry into the cluster as well as pull images from inside of the cluster (i.e. the kubelet). So I created a kind cluster exposing the service's port to the host using the `extraPortMappings` configuration option, changed `/etc/hosts` to let `kind-control-plane` point to 127.0.0.1 and change the `ClusterIP` service to be a `NodePort` service:

```sh
$ kind create cluster --config=- <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30443
    hostPort: 30443
    listenAddress: "127.0.0.1"
    protocol: tcp
EOF
Creating cluster "kind" ...
[...]
$ k create -f docker-registry.yaml
namespace/registry created
secret/registry created
deployment.apps/registry created
service/registry created
$ docker push kind-control-plane:30443/nginx:1.19.4
[...]
$ k run nginx --image=kind-control-plane:30443/nginx:1.19.4
pod/nginx created
$ k describe pod nginx
[...]
  Normal   Pulling    7s (x3 over 66s)   kubelet            Pulling image "kind-control-plane:30443/nginx:1.19.4"
  Warning  Failed     7s (x3 over 50s)   kubelet            Error: ErrImagePull
  Warning  Failed     7s (x2 over 38s)   kubelet            Failed to pull image "kind-control-plane:30443/nginx:1.19.4": rpc error: code = Unknown desc = failed to pull and unpack image "kind-control-plane:30443/nginx:1.19.4": failed to resolve reference "kind-control-plane:30443/nginx:1.19.4": failed to do request: Head https://kind-control-plane:30443/v2/nginx/manifests/1.19.4: x509: certificate signed by unknown authority
```

Oh well, that is somehow expected. I created a self-signed certificate to back the registry's HTTPS transport so somehow I now had to make kubelet aware of the CA certificate.

## The last step 🏁

To make kubelet (or rather containerd) aware of the new CA certificate, I had to copy it into the Docker container that's running the cluster node (this is a single-node cluster, after all):

```sh
$ docker cp /tmp/tls.crt kind-control-plane:/usr/local/share/ca-certificates/
$ docker exec -t kind-control-plane update-ca-certificates
Updating certificates in /etc/ssl/certs...
1 added, 0 removed; done.
Running hooks in /etc/ca-certificates/update.d...
done.
$ k run nginx --image=kind-control-plane:30443/nginx:1.19.4
pod/nginx created
$ k get pod nginx -w
NAME    READY   STATUS              RESTARTS   AGE
nginx   0/1     ContainerCreating   0          0s
nginx   1/1     Running             0          2s
```

Et voilà! The table is set. An improvement to having to have the CA certificate file laying around in my filesystem, I just extraced it from the `Secret` in the cluster.

## The Complete Rundown 🏎

1. Download the [Docker registry manifest](/downloads/docker-registry.yaml)

1. Install the registry and configure the cluster node:

   ```sh
   $ kind create cluster --config=- <<EOF
   kind: Cluster
   apiVersion: kind.x-k8s.io/v1alpha4
   nodes:
   - role: control-plane
     extraPortMappings:
     - containerPort: 30443
       hostPort: 30443
       listenAddress: "127.0.0.1"
       protocol: tcp
   EOF
   $ k create -f docker-registry.yaml
   $ k -n registry get secret registry -o jsonpath='{.data.tls\.crt}'|base64 -d|docker exec -i kind-control-plane sh -c "cat - > /usr/local/share/ca-certificates/registry-ca.crt && update-ca-certificates && systemctl restart containerd.service"
   ```

1. Make the service available with the node's name (the `grep` makes sure we're not adding a 2nd entry):

   ```sh
   grep -E ' kind-control-plane( |$)' /etc/hosts || echo '127.0.0.1 kind-control-plane' | sudo tee -a /etc/hosts
   ```

1. Push an image and create a test pod:

   ```sh
   $ docker pull nginx:1.19.4
   $ docker tag nginx:1.19.4 kind-control-plane:30443/nginx:1.19.4
   $ docker push kind-control-plane:30443/nginx:1.19.4
   $ k run nginx --image=kind-control-plane:30443/nginx:1.19.4
   $ k get pod nginx -w
   ```
