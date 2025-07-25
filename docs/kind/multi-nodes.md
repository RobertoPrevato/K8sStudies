When I first tried *kind*, I was a bit surprised to see that it creates by default a
single Docker container to simulate a whole cluster. I was expecting it would use at
least two containers to separate the Kubernetes _control plane_ from a _worker node_,
to mimic more closely a real Kubernetes environment.

Anyway, Kind supports multi-node clusters. Unsurprisingly, we can edit the _kind_ configuration
file to include more nodes.

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
      - hostPath: /home/ropt/stores
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
      - hostPath: /home/ropt/stores
        containerPath: /home/stores
```

Let's delete the previous cluster and create a new one using the new
configuration file.

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

I tried to apply a `nodeSelector` to each section describing containers, and to deploy the ingress this way.

```bash
kubectl apply -f deploy-ingress-nginx.yaml
```

**TODO: continua qua.**

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
