---
title: K3s - Lightweight Kubernetes
---

After practicing with Kind for a while, I wanted to explore another lightweight
Kubernetes distribution that's gaining popularity: **K3s**. **K3s** is a better fit for
local environments, as it's designed also for **production** workloads and it works well
across system reboots.

## What is K3s?

[K3s](https://k3s.io/) is a certified Kubernetes distribution designed to be lightweight and easy to install. Developed by [Rancher Labs](https://rancher.com/) (now part of SUSE), K3s packages Kubernetes as a single binary of less than 100MB that requires minimal resources to run.

The name "K3s" is a play on "K8s" (the common abbreviation for Kubernetes - with 8 letters between K and s). The "3" in K3s represents that it removes 5 from the 8 in K8s, signifying its lightweight nature.

K3s is designed to be lightweight but robust, and it installs
itself as a **systemd service**, which means:

- It **automatically starts on boot**.
- It **restores the Kubernetes control plane** and workloads after a reboot.
- It **persists cluster state** in `/var/lib/rancher/k3s`.

By default, K3s includes:

- An ingress controller: [**Traefik**](https://traefik.io/traefik).
- A built-in service load balancer.
- A local storage provisioner.
- A CNI (Container Network Interface).
- A network policy controller.

Each of these components can be disabled if not needed, or replaced with alternatives.

## Why K3s for Kubernetes Learning?

As I dive deeper into Kubernetes, K3s offers several advantages:

- **Simplified installation**: A single binary that can be installed with one command
- **Lower resource requirements**: Can run on machines with as little as 512MB RAM
- **Full Kubernetes compatibility**: Despite being lightweight, it's a fully CNCF-certified Kubernetes distribution
- **Production-ready**: Not just for learning - it can be used in production environments
- **Perfect for local development**: Fast startup time and low overhead

## Key Features of K3s

- **Single binary packaging**: Entire Kubernetes system bundled into one file
- **Embedded storage with SQLite**: No need for etcd (though it can be configured)
- **Simplified management**: Automatic TLS certificate generation and simplified kubeconfig setup
- **Packaged components**: Includes essential add-ons like CoreDNS, Traefik Ingress, and local storage provider
- **Easy cluster formation**: Simple to create multi-node clusters with a join token
- **Optimized for ARM**: Works well on Raspberry Pi and other ARM devices

## How K3s Differs from Standard Kubernetes

K3s achieves its lightweight status by:

1. Removing legacy and alpha features
2. Removing in-tree cloud providers and storage drivers
3. Using containerd instead of Docker by default
4. Using SQLite as the default storage backend instead of etcd
5. Bundling essential components that are typically installed separately

## Basic Installation

Installing K3s is simple:

```bash
# Install server
curl -sfL https://get.k3s.io | sh -

# Verify installation
sudo k3s kubectl get nodes
```

To configure `kubectl` access without using `sudo`, you can either:

- export the KUBECONFIG environment variable:

```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
```

- or merge the kubeconfig file:

```bash
# First copy to a file you can access
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/k3s-config
sudo chown $(id -u):$(id -g) ~/.kube/k3s-config

# Then merge it with your existing config
KUBECONFIG=~/.kube/config:~/.kube/k3s-config kubectl config view --flatten > ~/.kube/merged-config
mv ~/.kube/merged-config ~/.kube/config

# Switch context:
kubectl config use-context default
```

### Joining worker nodes

To join another computer as a worker node to the cluster:

```bash
# On the server, get the node token
sudo cat /var/lib/rancher/k3s/server/node-token

# On the worker
curl -sfL https://get.k3s.io | K3S_URL=https://server-ip:6443 K3S_TOKEN=token-from-server sh -
```

Replacing `server-ip` and `token-from-server` with the actual values.

## Use Cases for K3s

- **Learning environment**: Perfect for practicing Kubernetes concepts
- **Development workstations**: Run Kubernetes locally without heavy resource usage
- **Edge computing**: Deploy in resource-constrained environments
- **IoT devices**: Run on ARM devices like Raspberry Pi
- **CI/CD environments**: Fast startup makes it ideal for testing pipelines
- **Small production deployments**: Suitable for smaller workloads and teams

## My K3s Learning Journey

I plan to explore K3s by setting up a local cluster on my machine, deploying applications, and experimenting with various Kubernetes features.

The subsequent pages in this section will document my experiences with K3s, including deployments, configurations, and lessons learned.
