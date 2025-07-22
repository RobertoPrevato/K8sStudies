# Creating a Kubernetes Cluster with Kind

<img src="https://kind.sigs.k8s.io/logo/logo.png" alt="Kind logo" width="200"/>

## Introduction

Creating a Kubernetes cluster using **Kind** can be achieved using the command:

```bash
kind create cluster
```

This command will create a local Kubernetes cluster using a single Docker container
to simulate the cluster, using a pre-built node image.

![Kind create cluster](https://kind.sigs.k8s.io/images/kind-create-cluster.png)

To see the docker containers created by Kind, you can run:

```bash
docker ps
```

This will show you the containers running, including the one created by Kind for the
Kubernetes cluster.

```bash
$ docker ps
CONTAINER ID   IMAGE                  COMMAND                  CREATED        STATUS          PORTS                                                                 NAMES
8113bd868805   kindest/node:v1.33.1   "/usr/local/bin/entr…"   47 hours ago   Up 19 minutes   0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp, 127.0.0.1:43869->6443/tcp   kind-control-plane
```

By default, the cluster will be created with a single node named `kind-control-plane`,
which is sufficient for local development and testing. I immediately tried
creating a cluster with multiple worker nodes to test a more realistic scenario, but I will keep this exercise for later.

After creating a cluster, you can use `kubectl` to interact with it:

```bash
kubectl cluster-info --context kind-kind
```

For instance, to list the namespaces in the cluster, you can run:

```bash
kubectl get namespaces
```

This will show you the default namespaces created by Kind, such as `kube-system`, `kube-public`, and `default`. To see the list of pods running in the `kube-system` namespace, you can run `kubectl get pods -n kube-system`:

```bash
$ kubectl get pods -n kube-system
NAME                                         READY   STATUS    RESTARTS      AGE
coredns-674b8bbfcf-j7772                     1/1     Running   2 (32m ago)   47h
coredns-674b8bbfcf-w26pb                     1/1     Running   2 (32m ago)   47h
etcd-kind-control-plane                      1/1     Running   2 (32m ago)   47h
kindnet-8bnnr                                1/1     Running   2 (32m ago)   47h
kube-apiserver-kind-control-plane            1/1     Running   2 (32m ago)   47h
kube-controller-manager-kind-control-plane   1/1     Running   2 (32m ago)   47h
kube-proxy-xdxzp                             1/1     Running   2 (32m ago)   47h
kube-scheduler-kind-control-plane            1/1     Running   2 (32m ago)   47h
```

Clusters created with Kind are ephemeral, meaning they can be easily created and deleted.

To delete the cluster, you can run:

```bash
kind delete cluster
```

This will remove the cluster and all associated resources, including the Docker container used to simulate the cluster.

Being ephemeral, Kind clusters are ideal for local development and testing, allowing you to quickly spin up a cluster,
test your applications, and then tear it down when you're done. Kind clusters are not meant for production use, and they
are not designed to be persistent or long-lived, and they are not guaranteed to be stable across system reboots or
Docker daemon restarts, as changes in network configuration or Docker settings can affect the cluster's behavior.

They can probably be used effectively also for small development teams.

/// admonition | MiniKube.
    type: info

If having a system that is more stable across reboots is important, you can consider using
[MiniKube](https://minikube.sigs.k8s.io/docs/), with a [_VM driver_](https://minikube.sigs.k8s.io/docs/drivers/), like VirtualBox.

///

Kind also supports running multiple clusters, and running clusters using multiple Docker containers for each node in the
cluster, which can be useful for testing multi-node Kubernetes scenarios. My notes start with a single-node cluster, and
leave for later scenarios with multiple nodes.

## Next steps

The next page describes my first exercise with Kubernetes: how to [host several web
applications](./web-hosting.md) in a Kubernetes cluster.
