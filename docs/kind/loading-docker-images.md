Following a system restart, when I didn't have an internet connection, my application
stopped working because Kubernetes could not pull the Docker image
`robertoprevato/fortunecookies:latest` from Docker Hub.

When you use the `:latest` tag, Kubernetes will attempt to pull the image from the
source registry (e.g., Docker Hub) on each pod restart by default. This means your
workloads deployed to Kubernetes may fail to start if a connection to the source
registry is unavailable, or if the containers registry is unreachable.

While looking for information on this subject, I came across this great
article:

- [How I Wasted a Day Loading Local Docker Images](https://iximiuz.com/en/posts/kubernetes-kind-load-docker-image/).

I recommend reading this article.

## Checking which Docker images are loaded in Kind

To verify which Docker images are loaded in the Kind cluster, enter the
`kind-control-plane` using the Docker CLI:

```bash
docker exec -it kind-control-plane bash
```

This enters the Docker container using `bash`. Then to see the list of
images in the container run the following command:

```bash
crictl images
```

``` {hl_lines="5"}
root@kind-control-plane:/# crictl images
IMAGE                                                TAG                  IMAGE ID            SIZE
registry.k8s.io/ingress-nginx/controller             <none>               11b916a025f02       105MB
docker.io/kindest/kindnetd                           v20250512-df8de77b   409467f978b4a       44.4MB
docker.io/robertoprevato/fortunecookies              latest               06c0613648b0c       141MB
registry.k8s.io/coredns/coredns                      v1.12.0              1cf5f116067c6       20.9MB
registry.k8s.io/etcd                                 3.5.21-0             499038711c081       58.9MB
registry.k8s.io/kube-scheduler-amd64                 v1.33.1              398c985c0d950       74.5MB
registry.k8s.io/kube-scheduler                       v1.33.1              398c985c0d950       74.5MB
registry.k8s.io/pause                                3.10                 873ed75102791       320kB
registry.k8s.io/ingress-nginx/kube-webhook-certgen   <none>               a62eeff05ba51       26.2MB
docker.io/kindest/local-path-helper                  v20241212-8ac705d0   baa0d31514ee5       3.08MB
docker.io/kindest/local-path-provisioner             v20250214-acbabc1a   bbb6209cc873b       22.5MB
registry.k8s.io/kube-apiserver-amd64                 v1.33.1              c6ab243b29f82       103MB
registry.k8s.io/kube-apiserver                       v1.33.1              c6ab243b29f82       103MB
registry.k8s.io/kube-controller-manager-amd64        v1.33.1              ef43894fa110c       95.7MB
registry.k8s.io/kube-controller-manager              v1.33.1              ef43894fa110c       95.7MB
registry.k8s.io/kube-proxy-amd64                     v1.33.1              b79c189b052cd       99.1MB
registry.k8s.io/kube-proxy                           v1.33.1              b79c189b052cd       99.1MB
```

/// admonition | crictl
    type: note

The Kind control plane node runs Kubernetes using `containerd` as its container runtime,
not Docker. Therefore, the `docker` CLI is not available inside the node.
Instead, you should use `crictl`, which is a CLI for CRI-compatible container runtimes
like containerd.

The *Container Runtime Interface* (CRI) is a set of specifications that define how
container runtimes should behave in a Kubernetes environment. CRI-compatible tools, like
`crictl`, are used to interact with container runtimes that are compatible with the CRI
specification, enabling Kubernetes to manage containers. While Docker historically had
its own runtime, Kubernetes adopted the CRI to allow for more flexibility and support
for different runtimes like containerd and CRI-O.

Initially Kubernetes was tightly coupled with Docker (which is understandable, as it was
Docker to revolutionize containerization since in 2013).

///

## How to prevent Kubernetes from re-fetching images

To prevent Kubernetes from re-fetching container images upon restart, there are two
options:

1. Using a specific tag for the Docker image, instead of `:latest`.
2. Applying an `imagePullPolicy` to the container's configuration.

```yaml {hl_lines="4"}
      containers:
        - name: fortune-cookies
          image: robertoprevato/fortunecookies:latest
          imagePullPolicy: IfNotPresent
```

## Loading images manually into Kind

To load images manually from the host into Kind, you can use the `load` command offered
by the `kind` CLI.

For instance, to load a `robertoprevato/mvcdemo:0.0.1` image into Kind:

```bash
kind load docker-image robertoprevato/mvcdemo:0.0.1
```

This allows you to load images that are built locally into Kind, removing the need to
fetch them from a container registry.

## For more information

Refer to the Kind documentation: [*Loading an Image Into Your Cluster*](https://kind.sigs.k8s.io/docs/user/quick-start/#loading-an-image-into-your-cluster).

## Next steps

My next exercise describes how to simulate [_multiple nodes in Kind_](./multi-nodes.md).
