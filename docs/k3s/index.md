---
title: K3s - Lightweight Kubernetes
---

After practicing with Kind for a while, I wanted to explore another lightweight
Kubernetes distribution that's gaining popularity: **K3s**. **K3s** seems to be a better
fit for shared and persistent development environments, as it's designed also for
**production** workloads and it works well across system reboots.

## What is K3s?

[K3s](https://k3s.io/) is a certified Kubernetes distribution designed to be lightweight and easy to install. Developed by [Rancher Labs](https://rancher.com/) (now part of SUSE), K3s packages Kubernetes as a single binary of less than 100MB that requires minimal resources to run.

## Why K3s for Kubernetes Learning?

As I dive deeper into Kubernetes, K3s offers several advantages:

- **Simplified installation**: A single binary that can be installed with one command
- **Lower resource requirements**: Can run on machines with as little as 512MB RAM
- **Full Kubernetes compatibility**: Despite being lightweight, it's a fully CNCF-certified Kubernetes distribution
- **Production-ready**: Not just for learning - it can be used in production environments
- **Perfect for local development**: Fast startup time and low overhead

Fun fact: **Jeff Geerling** made a video on running a K3s cluster on a group of Raspberry Pi!

<iframe width="560" height="315" src="https://www.youtube.com/embed/N4bfNefjBSw?si=12e039MlolDlxUPN" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

## Default Installation

To install K3s with default settings:

```bash
curl -sfL https://get.k3s.io | sh -

# verify installation…
sudo k3s kubectl get nodes
```

To configure `kubectl` access without using `sudo`, you can either export the `KUBECONFIG` environment variable:

```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
```

or merge the `kubeconfig` file:

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

- **Learning environment**: Perfect for practicing Kubernetes concepts.
- **Development workstations**: Run Kubernetes locally without heavy resource usage.
- **Edge computing**: Deploy in resource-constrained environments.
- **IoT devices**: Run on ARM devices like Raspberry Pi.
- **CI/CD environments**: Fast startup makes it ideal for testing pipelines.
- **Small production deployments**: Suitable for smaller workloads and teams.

## My first exercise

For my first exercise, I wanted to try adapting the example about [volume mounting](../kind/mounting-volumes.md) to use K3s and persistent volumes, with Traefik instead of NGINX. This exercise includes exposing a web app with a self-signed SSL certificate.

The README in `./examples/07-k3s-local-pv` includes commands to create the
deployments.

---

There is an issue that, since my demo Fortune Cookies app expects a SQLite
database populated with a `cookie` table and doesn't create one when using a
volume mount, I needed to fix it manually after applying the `cookies.yaml`
deployment. This was useful anyway to learn where K3s stores persistent volumes on
the host system by default: `/var/lib/rancher/k3s/storage`.

```bash
sudo su

# cd in the default folder used by K3s for persistent volumes
cd /var/lib/rancher/k3s/storage

cd pvc-*_fortunecookies*

# copy a populated app.db (like the one in the examples folder) into here
cp /path_to_your_repo/examples/07-k3s-local-pv/data/app.db .
```

---

At this point, I hoped the service would work like it did when I made the same
with Kind and NGINX, but it didn't work. While investigating, I found the
following error:

```bash {hl_lines="3"}
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik

2025-09-16T06:26:53Z ERR Cannot create service error="externalName services not allowed: common-ingress/fortune-cookies" ingress=common-ingress namespace=common-ingress providerName=kubernetes serviceName=fortune-cookies servicePort=&ServiceBackendPort{Name:,Number:80,}
```

> *2025-09-16T06:26:53Z ERR Cannot create service error="externalName services
> not allowed: common-ingress/fortune-cookies" ingress=common-ingress
> namespace=common-ingress providerName=kubernetes serviceName=fortune-cookies
> servicePort=&ServiceBackendPort{Name:,Number:80,}*

While using `ExternalName` services worked out of the box with Kind and NGINX, they are
not allowed in the default K3s installation because Traefik does not allow them by default
 (see [_allowExternalNameServices_](https://doc.traefik.io/traefik/reference/install-configuration/providers/kubernetes/kubernetes-crd/#providers-kubernetesCRD-allowExternalNameServices)).
The purpose of `ExternalName` here was to keep the common ingress controller
into a dedicated workspace, making it capable of exposing many workloads, each
residing in a dedicated namespace.

To enable `ExternalNameServices`, apply the following settings:

```yaml
# traefik-config.yaml
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: traefik
  namespace: kube-system
spec:
  valuesContent: |-
    providers:
      kubernetesIngress:
        allowExternalNameServices: true
```

```bash
kubectl apply -f traefik-config.yaml
```

And try recreating the `common-ingress` like before. Now Traefik is failing in
a different way:

```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik

2025-09-16T07:47:03Z INF Starting provider *acme.ChallengeTLSALPN
2025-09-16T07:47:03Z INF label selector is: "" providerName=kubernetescrd
2025-09-16T07:47:03Z INF Creating in-cluster Provider client providerName=kubernetescrd
2025-09-16T07:47:03Z INF ExternalName service loading is enabled, please ensure that this is expected (see AllowExternalNameServices option) providerName=kubernetes
2025-09-16T07:47:42Z INF Updated ingress status ingress=common-ingress namespace=common-ingress
2025-09-16T07:47:42Z ERR Cannot create service error="service not found" ingress=common-ingress namespace=common-ingress providerName=kubernetes serviceName=fortune-cookies servicePort=&ServiceBackendPort{Name:,Number:80,}
2025-09-16T07:47:42Z ERR Error while updating ingress status error="failed to update ingress status common-ingress/common-ingress: Operation cannot be fulfilled on ingresses.networking.k8s.io \"common-ingress\": the object has been modified; please apply your changes to the latest version and try again" ingress=common-ingress namespace=common-ingress providerName=kubernetes
2025-09-16T07:47:42Z ERR Cannot create service error="service not found" ingress=common-ingress namespace=common-ingress providerName=kubernetes serviceName=fortune-cookies servicePort=&ServiceBackendPort{Name:,Number:80,}
2025-09-16T07:47:42Z ERR Cannot create service error="service not found" ingress=common-ingress namespace=common-ingress providerName=kubernetes serviceName=fortune-cookies servicePort=&ServiceBackendPort{Name:,Number:80,}
2025-09-16T07:47:42Z ERR Cannot create service error="service not found" ingress=common-ingress namespace=common-ingress providerName=kubernetes serviceName=fortune-cookies servicePort=&ServiceBackendPort{Name:,Number:80,}
```

It claims the service is not found. However, it exists:

```bash
kubectl get svc -n common-ingress

NAME              TYPE           CLUSTER-IP   EXTERNAL-IP                                        PORT(S)   AGE
fortune-cookies   ExternalName   <none>       fortune-cookies.fortunecookies.svc.cluster.local   80/TCP    2m37s
```

And to verify that DNS resolution works inside the cluster:

```bash
kubectl run -n common-ingress dns-test --rm -it --image=busybox --restart=Never -- sh

# Inside the pod:
nslookup fortune-cookies.fortunecookies.svc.cluster.local

/ # nslookup fortune-cookies.fortunecookies.svc.cluster.local
Server:		10.43.0.10
Address:	10.43.0.10:53


Name:	fortune-cookies.fortunecookies.svc.cluster.local
Address: 10.43.10.44
```

From the pod, it is even possible to get proper responses from the app running
in the `fortunecookies` namespace.

```bash
kubectl run -n common-ingress curltest --rm -it --image=curlimages/curl --restart=Never -- sh

curl http://fortune-cookies.fortunecookies.svc.cluster.local/cookies/

<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="utf-8">
    <!-- Force latest IE rendering engine or ChromeFrame if installed -->
    <!--[if IE]><meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1"><![endif]-->
    <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
    <title>Fortune Cookies</title>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <meta name="description" content="Project template to create web applications with MVC architecture using BlackSheep web framework." />
    <link rel="icon" type="image/svg+xml" sizes="any"
        href="data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>🥠</text></svg>" /><link rel="stylesheet" href="/cookies/styles/public.css" /></head>

<body id="page-top">
    <nav id="main-nav">
        <h1>Fortune Cookies</h1>
    </nav>

    <div id="content"><div>
    <p class="cookie"><i>🥠&nbsp;</i>Success is a journey, not a destination.</p>
</div></div><!--
Example
-->
</body>
```

Then, with the assistance of `Claude Sonnet 3.7` which pointed me to the right
direction, I simply restarted Traefik:

```bash
kubectl -n kube-system rollout restart deployment traefik
```

And it started working! :tada: :tada: :tada:

### Inspecting logs

To inspect the logs of the running deployment:

```bash
# in one terminal…
kubectl logs -f deployment/fortune-cookies -n fortunecookies

# in another terminal…
curl -k https://www.neoteroi.xyz/cookies/
```

## Summary

The first impressions with K3s are very positive.
