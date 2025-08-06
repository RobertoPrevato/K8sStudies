When I first tried *kind*, I was a bit surprised to see it creates by default a single
Docker container to simulate a whole cluster. I was expecting it would use at least two
containers to separate the Kubernetes _control plane_ from a _worker node_, to mimic
more closely a real Kubernetes environment. Anyway, Kind supports multi-node clusters.
We can edit the _kind_ configuration file to include more nodes.

## Creating a cluster with multiple nodes

Starting from the `kind.yaml` of the last example, I tried creating a cluster with one
control plane and one worker node.

```yaml {linenums="1" hl_lines="12-15"}
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
  - role: worker
    extraMounts:
      - hostPath: /tmp/stores
        containerPath: /home/stores
```

Now, there is something more worth considering. So far we ran the _ingress controller_
on the `control-plane` node. In a more realistic scenario, the `ingress controller` is
deployed on a worker node instead. With Kind, there is the complication that I want to
use `extraPortMappings` to map the ports from my host to the ports of a node. Therefore
I need a way to specify that the ingress controller should be provisioned on the worker
node with mapped ports. To achieve this, we can add extra labels to a worker node.

Let's say, `ingress-node: "true"` for the worker node that will run the ingress
controller and `apps-node: "true"` for the worker node with mounts that can run a
the _Fortune Cookies_ app from the last example.

```yaml {linenums="1" hl_lines="5-8 16-17"}
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
    labels:
      ingress-node: "true"
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
  - role: worker
    labels:
      apps-node: "true"
    extraMounts:
      - hostPath: /tmp/stores
        containerPath: /home/stores
```

Let's delete the previous cluster and create a new one using the new configuration file.

```bash
kind delete cluster

kind create cluster --config kind.yaml
```

Note how the third line now has three package emojis 📦 as the configuration file
describes three nodes:

```bash {hl_lines="4"}
$ kind create cluster --config kind.yaml
Creating cluster "kind" ...
 ✓ Ensuring node image (kindest/node:v1.33.1) 🖼
 ✓ Preparing nodes 📦 📦 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
 ✓ Joining worker nodes 🚜
Set kubectl context to "kind-kind"
You can now use your cluster with:

kubectl cluster-info --context kind-kind

Have a question, bug, or feature request? Let us know! https://kind.sigs.k8s.io/#community 🙂
```

And true enough, *kind* spinned up three Docker containers:

```bash
$ docker ps
CONTAINER ID   IMAGE                  COMMAND                  CREATED         STATUS         PORTS                                      NAMES
2081234ce071   kindest/node:v1.33.1   "/usr/local/bin/entr…"   5 minutes ago   Up 5 minutes                                              kind-worker2
cd56624175d5   kindest/node:v1.33.1   "/usr/local/bin/entr…"   5 minutes ago   Up 5 minutes   0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp   kind-worker
be74048526e3   kindest/node:v1.33.1   "/usr/local/bin/entr…"   5 minutes ago   Up 5 minutes   127.0.0.1:34545->6443/tcp                  kind-control-plane
```

## Configuring Node Selectors

Previously I deployed the ingress controller downloading
`https://kind.sigs.k8s.io/examples/ingress/deploy-ingress-nginx.yaml` directly, now I
need to obtain a copy of this file and modify it to ensure the controller is deployed on
the worker node with the label `ingress-node: "true"`. To achieve this, we need to
specify a `nodeSelector` rule in the ingress controller deployment.

```yaml
spec:
  template:
    spec:
      nodeSelector:
        ingress-node: "true"
```

I applied a `nodeSelector` to each section describing containers, to deploy the ingress
controller on a node with the label `ingress-node: "true"`.

```bash
kubectl apply -f deploy-ingress-nginx.yaml
```

The deployment should succeed. You can monitor it like described in [the first exercise](./web-hosting.md),
using `kubectl`.

### Node selector on the cookies app

```yaml {linenums="1" hl_lines="15-16"}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fortune-cookies
spec:
  replicas: 1
  selector:
    matchLabels:
      app: fortune-cookies
  template:
    metadata:
      labels:
        app: fortune-cookies
    spec:
      nodeSelector:
        apps-node: "true"
      containers:
        - name: fortune-cookies
          image: robertoprevato/fortunecookies:latest
          imagePullPolicy: IfNotPresent
          env:
            - name: APP_ROUTE_PREFIX
              value: cookies
          ports:
            - containerPort: 80
          readinessProbe:
            httpGet:
              path: /cookies/
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /cookies/
              port: 80
            initialDelaySeconds: 15
            periodSeconds: 20
          volumeMounts:
            - name: store-volume
              mountPath: /home/store
      volumes:
        - name: store-volume
          hostPath:
            path: /home/stores/cookies
            type: Directory
---
apiVersion: v1
kind: Service
metadata:
  name: fortune-cookies
spec:
  ports:
    - port: 80
      targetPort: 80
  selector:
    app: fortune-cookies
  type: ClusterIP
---
```

Let's redeploy the fortune cookies app using the modified `cookies.yaml` that includes
the node selector setting:

```bash
kubectl create namespace fortunecookies

kubectl apply -n fortunecookies -f cookies.yaml
```

And finally let's deploy the ingress rules like in [the previous example](./mounting-volumes.md):

```bash
kubectl create namespace common-ingress

cd ssl
kubectl create secret tls neoteroi-xyz-tls \
  --cert=neoteroi-xyz-tls.crt \
  --key=neoteroi-xyz-tls.key \
  -n common-ingress

cd ../
kubectl apply -n common-ingress -f common-ingress.yaml
```

## Hurray!

It works! [https://www.neoteroi.xyz/cookies/](https://www.neoteroi.xyz/cookies/) :eyes:

![Fortune Cookie Demo in Worker node](/K8sStudies/img/fortune-cookies-multi-nodes.png)

However, to be absolutely certain that the process is simulated on a worker node, let's
check entering the correct container.

```bash
docker ps
```

In the output, you can see:

- the node dedicated to the `control-plane`
- the worker node dedicated to the ingress, which is the one with ports mapped from the
  host, named `kind-worker`.
- the worker node dedicated to running apps (with `apps-node: "true"` label), named
  `kind-worker2`, recognizable because it doesn't have mapped ports.

```bash {linenums="1"}
$ docker ps
CONTAINER ID   IMAGE                  COMMAND                  CREATED          STATUS          PORTS                                      NAMES
ae0f94c2dced   kindest/node:v1.33.1   "/usr/local/bin/entr…"   16 minutes ago   Up 16 minutes   0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp   kind-worker
71aafd87e5c4   kindest/node:v1.33.1   "/usr/local/bin/entr…"   16 minutes ago   Up 16 minutes   127.0.0.1:35673->6443/tcp                  kind-control-plane
11e5a2e13c17   kindest/node:v1.33.1   "/usr/local/bin/entr…"   16 minutes ago   Up 16 minutes                                              kind-worker2
```

We can verify that the _fortune cookies_ app is running in `kind-worker2` by entering
the container and checking the processes:

```bash
# enter the container
docker exec -it kind-worker2 bash

# list processes
ps aux
```

And true enough, you can see that the `uvicorn` process is running in the `kind-worker2`
container, visible on lines 15-16 of the output below, matching the `CMD` parameter of
the [demo apps `Dockerfile`](https://github.com/RobertoPrevato/SQLiteWebDemo/blob/main/Dockerfile#L46).:

```bash {linenums="1" hl_lines="15-16"}
root@kind-worker2:/# ps aux
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root           1  0.0  0.0  20416 11368 ?        Ss   15:49   0:00 /sbin/init
root          93  0.0  0.0  24824 10240 ?        Ss   15:49   0:00 /lib/systemd/systemd-journald
root         108  1.2  0.3 2605304 61432 ?       Ssl  15:49   0:17 /usr/local/bin/containerd
root         222  1.1  0.5 2639680 90528 ?       Ssl  15:50   0:14 /usr/bin/kubelet --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.con
root         283  0.0  0.0 1233548 10604 ?       Sl   15:50   0:00 /usr/local/bin/containerd-shim-runc-v2 -namespace k8s.io -id bf1a20ef9bef832b
root         301  0.0  0.0 1233804 10604 ?       Sl   15:50   0:00 /usr/local/bin/containerd-shim-runc-v2 -namespace k8s.io -id a3ced7b79cd27613
65535        337  0.0  0.0   1020   640 ?        Ss   15:50   0:00 /pause
65535        342  0.0  0.0   1020   640 ?        Ss   15:50   0:00 /pause
root         382  0.0  0.3 1298256 59096 ?       Ssl  15:50   0:00 /usr/local/bin/kube-proxy --config=/var/lib/kube-proxy/config.conf --hostname
root         471  0.0  0.2 1281608 46128 ?       Ssl  15:50   0:00 /bin/kindnetd
root         740  0.0  0.0 1233868 10612 ?       Sl   15:57   0:00 /usr/local/bin/containerd-shim-runc-v2 -namespace k8s.io -id e1ea1d3886e2b34d
65535        764  0.0  0.0   1020   640 ?        Ss   15:57   0:00 /pause
root         832  0.0  0.0   2580  1408 ?        Ss   15:57   0:00 sh -c . venv/bin/activate && uvicorn "app.main:app" --host 0.0.0.0 --port 80
root         851  0.2  0.4 330940 75880 ?        Sl   15:57   0:02 /home/venv/bin/python /home/venv/bin/uvicorn app.main:app --host 0.0.0.0 --po
root        1005  0.3  0.0   4192  3328 pts/1    Ss   16:11   0:00 bash
root        1013  0.0  0.0   8092  4096 pts/1    R+   16:11   0:00 ps aux
```

## Following a restart…

Following a restart of the cluster, the system took several minutes to become responsive. This issue happened only once in several system restarts.

Initially it was giving a `Gateway Time Out` error, which is a common issue when the
ingress controller is not ready to handle requests.

![Gateway Time Out](/K8sStudies/img/fortune-cookies-gateway-time-out.png)

I verified the fortune cookies app was working and it started quickly, using the
commands:

```bash
kubectl get pods -n fortunecookies

kubectl describe pod <pod-name> -n fortunecookies

kubectl logs -p <pod-name> -n fortunecookies
```

```bash {linenums="1" hl_lines="1 6"}
$ kubectl get pods -n fortunecookies

NAME                               READY   STATUS    RESTARTS        AGE
fortune-cookies-7d56c4cff7-trr8k   1/1     Running   1 (8m38s ago)   15h

$ kubectl describe pod fortune-cookies-7d56c4cff7-trr8k -n fortunecookies
Name:             fortune-cookies-7d56c4cff7-trr8k
Namespace:        fortunecookies
Priority:         0
Service Account:  default
Node:             kind-worker2/172.18.0.4
Start Time:       Sat, 26 Jul 2025 17:57:14 +0200
Labels:           app=fortune-cookies
                  pod-template-hash=7d56c4cff7
Annotations:      <none>
Status:           Running
IP:               10.244.2.2
IPs:
  IP:           10.244.2.2
Controlled By:  ReplicaSet/fortune-cookies-7d56c4cff7
Containers:
  fortune-cookies:
    Container ID:   containerd://7e44b8db8259e108020902359c6ae55e06cf1ca8db6f5518217a5172f9b0cef6
    Image:          robertoprevato/fortunecookies:latest
    Image ID:       docker.io/robertoprevato/fortunecookies@sha256:d8c00d5ee9fc4849b740b12a22b258a65ed52cc5d84b0a3115c0814af9a1a7ce
    Port:           80/TCP
    Host Port:      0/TCP
    State:          Running
      Started:      Sun, 27 Jul 2025 08:59:23 +0200
    Last State:     Terminated
      Reason:       Unknown
      Exit Code:    255
      Started:      Sat, 26 Jul 2025 17:57:58 +0200
      Finished:     Sun, 27 Jul 2025 08:59:14 +0200
    Ready:          True
    Restart Count:  1
    Liveness:       http-get http://:80/cookies/ delay=15s timeout=1s period=20s #success=1 #failure=3
    Readiness:      http-get http://:80/cookies/ delay=5s timeout=1s period=10s #success=1 #failure=3
    Environment:
      APP_ROUTE_PREFIX:  cookies
    Mounts:
      /home/store from store-volume (rw)
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-htxvt (ro)
Conditions:
  Type                        Status
  PodReadyToStartContainers   True
  Initialized                 True
  Ready                       True
  ContainersReady             True
  PodScheduled                True
Volumes:
  store-volume:
    Type:          HostPath (bare host directory volume)
    Path:          /home/stores/cookies
    HostPathType:  Directory
  kube-api-access-htxvt:
    Type:                    Projected (a volume that contains injected data from multiple sources)
    TokenExpirationSeconds:  3607
    ConfigMapName:           kube-root-ca.crt
    Optional:                false
    DownwardAPI:             true
QoS Class:                   BestEffort
Node-Selectors:              apps-node=true
Tolerations:                 node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
                             node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
Events:
  Type    Reason          Age    From     Message
  ----    ------          ----   ----     -------
  Normal  SandboxChanged  8m33s  kubelet  Pod sandbox changed, it will be killed and re-created.
  Normal  Pulled          8m32s  kubelet  Container image "robertoprevato/fortunecookies:latest" already present on machine
  Normal  Created         8m32s  kubelet  Created container: fortune-cookies
  Normal  Started         8m32s  kubelet  Started container fortune-cookies
```

![Healthy fortune cookies container](/K8sStudies/img/fortune-cookies-healthy-k9s.png)

While I was investigating the status of the ingress controller, the system started
working.

The logs of the `ingress-nginx-controller` showed that the error was caused by DNS
resolution issues, indicating that the NGINX ingress controller was having trouble
resolving the DNS name `fortune-cookies.fortunecookies.svc.cluster.local` using the
cluster DNS service at `10.96.0.10:53`.

```bash
kubectl logs ingress-nginx-controller-5c47b49d7-8t69j -n ingress-nginx
```

```
2025/07/27 07:05:13 [error] 47#47: *5409 lua udp socket read timed out, context: ngx.timer
2025/07/27 07:05:13 [error] 47#47: *5409 recv() failed (111: Connection refused), context: ngx.timer
2025/07/27 07:05:13 [error] 47#47: *5409 [lua] dns.lua:152: dns_lookup(): failed to query the DNS server for fortune-cookies.fortunecookies.svc.cluster.local:
failed to receive reply from UDP server 10.96.0.10:53: timeout
```

According to _GitHub Copilot_, this is a common issue with multi-node clusters in *kind*,
where the DNS service may not be fully initialized or reachable at the time the ingress
controller starts.

This issue, however, does not occur at every restart. In some cases, the system becomes available more quickly, likely depending on the order in which pods are spun up.

/// details | Chat with GitHub Copilot :octicons-copilot-16:.

**RP:** Do you have any idea on why the cluster and the NGINX ingress took a very long
time to start, following a system restart in my Multi-nodes Kind setup described in my
documentation?

**GitHub Copilot:** Yes, this is a common issue with multi-node *kind* clusters,
especially after a system restart. Here are the most likely causes:

1. **Docker Network Initialization Delay** After a system restart, Docker needs to
   re-create its internal networks and start all containers. *Kind* clusters rely on
   Docker networking, and sometimes the containers (nodes) start before the network is
   fully ready, causing delays in pod scheduling and communication.

2. **Pod Scheduling and Node Readiness** Kubernetes waits for all nodes to become
   "Ready" before scheduling critical pods like the ingress controller. If any node is
   slow to start (due to Docker or resource contention), the ingress controller and
   other pods may be stuck in a pending or initializing state.

3. **Volume Mounts and HostPath Issues** If you use `hostPath` volumes (as in your
   setup), and the host directories are not available or are slow to mount after a
   reboot, pods depending on those mounts may fail to start or restart repeatedly.

4. **Image Pull/Container Startup Delays** If images are not cached locally or if there
   are issues with the container runtime, pulling images or starting containers can take
   longer after a restart.

5. **Ingress Controller Probes** The NGINX ingress controller uses liveness/readiness
   probes. If the controller starts before the network is fully functional, these probes
   can fail, causing Kubernetes to restart the pod or mark it as "Unhealthy" until the
   network stabilizes.

6. **Resource Contention** On local machines, especially with limited CPU/RAM, starting
   multiple Docker containers and all cluster components at once can overwhelm the
   system, leading to slow startups.

**What you can do:**
- Wait a few minutes after system boot before starting the cluster, to let Docker and
  its networks fully initialize.
- Check `docker ps` and `docker network ls` to ensure all containers and networks are
  up.
- Use `kubectl get nodes` and `kubectl describe node <node>` to check node readiness and
  events.
- Review pod events with `kubectl describe pod <pod>` for clues (e.g., probe failures,
  mount errors).
- Consider using `kind delete cluster` and `kind create cluster --config kind.yaml`
  after a reboot if issues persist.

**Summary:** This is mostly due to Docker and Kubernetes components racing to initialize
after a system restart, combined with the complexity of multi-node setups and hostPath
mounts. It is a known limitation of running multi-node clusters with *kind* on local
machines.

///

## Summary

In this exercise, we created a multi-node cluster with *kind* and deployed the _Fortune
Cookies_ app on a dedicated worker node. We also configured the ingress controller to
run on a separate worker node, allowing us to better simulate a realistic Kubernetes
environment.

Although *kind* is primarily a tool for local development, the use of **labels** and
**node selectors** to control pod placement is a fundamental concept in Kubernetes, and
is also important to run production workloads.

The cluster takes much longer to start after a system restart, which is a common issue
with multi-node *kind* clusters. This seems to be due to the time it takes for Docker to
initialize networks and containers, as well as the Kubernetes scheduler waiting for all
nodes to become ready.

We also saw how to inspect processes running in a container.
