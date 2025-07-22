This page describes my second exercise with Kubernetes. After completing the [first
exercise](./web-hosting.md), I wanted to learn how to _mount folders_ to persist data
for **containers** running in **pods**.

## Demo application

Since I needed a demo application to test volume mounting, I decided to create a web
application that returns _fortune cookies_ read from a
[_SQLite_](https://www.sqlite.org/) database. The application expects a SQLite
database in the `./store/` folder relative to the application's root (its _Current
Working Directory (CWD)_), and its homepage displays a random fortune cookie each time
it is refreshed. The screenshot below shows the homepage of the application:

![Fortune Cookies demo app](/img/fortune-cookies-demo.png)

---

The source code of the application is on GitHub at: [RobertoPrevato/SQLiteWebDemo](https://github.com/RobertoPrevato/SQLiteWebDemo).
The repository includes a `Dockerfile` to build a Docker image, and a `GitHub Workflow`
to build and push the image to [Docker Hub](https://hub.docker.com/r/robertoprevato/fortunecookies).

The Docker image can be pulled from Docker Hub with the following command:

```bash
docker pull robertoprevato/fortunecookies
```

/// note | Demo SQLite database.

The `SQLite` database expected by the application can be created using [*Alembic*](https://alembic.sqlalchemy.org/en/latest/), using the script
[`newdb.sh` included in the repository](https://github.com/RobertoPrevato/SQLiteWebDemo/blob/main/newdb.sh).

///

## Mounting volumes with Kind

Since I am still practicing with *kind*, I realized I needed to configure my *kind*
cluster to mount a folder from my host machine to the containers running in the cluster.

I decided to create a folder in my home directory, called "stores", planning to create a
subfolder for each application I want to run in the cluster. In this case, I created a
`cookies` subfolder to store the SQLite database for the fortune cookies application:

```
.
└── stores
    └── cookies
        └── app.db
```

I asked *GitHub Copilot*'s help to configure volume mounting in my *kind* cluster, and
it suggested the correct configuration to mount the host folder to the container
running in the cluster. I added the lines highlighted below to the *kind*
configuration file I created previously (_kind.yaml_):

```yaml {linenums="1" hl_lines="12-14"}
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
    extraMounts:
      - hostPath: /home/ropt/stores
        containerPath: /home/stores
```

This configuration mounts the host folder `/home/ropt/stores` to the `control-plane`'s
node container at the path `/home/stores`. I made this planning to later mount specific
subfolders into containers for specific `pods`.

In my case, my Linux user is named `ropt` and I am using the path `/home/ropt/stores`
for the source folder, but you should replace it with the path to the folder you created
on your host machine.

## Recreating the cluster

```bash
kind delete cluster
kind create cluster --config kind.yaml
```

This command will delete the existing cluster and create a new one using the updated
configuration file. The new cluster will have the host folder mounted as specified.

## Deploying the application

For this exercise, use the files in the `examples/02-mounting-volumes/` folder.

Repeating the steps from the [first exercise](./web-hosting.md), I created the necessary
ingress controller:

```bash
kubectl apply -f https://kind.sigs.k8s.io/examples/ingress/deploy-ingress-nginx.yaml

kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

Then, I created the namespace for the application and deployed the fortune cookies
application. Note the section to configure the mount point for the SQLite database:

```yaml {linenums="1" hl_lines="19-21 40-47"}
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
      tolerations:
        - key: "CriticalAddonsOnly"
          operator: "Exists"
          effect: "NoSchedule"
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

I created the application deployment and service with the following command:

```bash
kubectl create namespace fortunecookies

kubectl apply -n fortunecookies -f cookies.yaml
```

Finally, I created a namespace for the common ingress and applied the ingress
rules to direct traffic to the application, including the self-signed TLS certificate
like described in the [first exercise](./web-hosting.md).

Remember to generate the self-signed TLS certificate and key files, and place them in the
`ssl/` folder in the `examples/02-mounting-volumes/` directory. Then, run the
following commands to create the TLS secret and apply the ingress rules:

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

The application is now running in the cluster, and you can access it using the
following URL: [*https://neoteroi.xyz/cookies/*](https://neoteroi.xyz/cookies/).

![Fortune Cookies](/img/fortune-cookies-app.png)

/// admonition | Using SQLite for web applications.
    type: example

SQLite can be successfully used for smaller to medium-sized web applications (which is
to say, most websites). SQLite is a popular option for many websites and applications
due to its simplicity, ease of use, and lack of a separate server process.

SQLite is designed for situations where a single process (or a single instance of an
application) writes to the database, but multiple processes or instances can safely read
from it at the same time.

There are some limitations to be aware of:

- **Reads:** Multiple instances can read from the same SQLite database file concurrently
  without issues.
- **Writes:** Only one instance should write to the database at a time. SQLite uses file
  locks to prevent simultaneous writes, but this can lead to contention and performance
  problems if multiple writers are present.

For web applications running in Kubernetes, it's best to use SQLite only if you have a
single application instance writing to the database, or if your workload is read-heavy
and you can ensure only one writer. For multiple writers, a client-server database like
PostgreSQL is a better choice.

There are attempts at creating strategies to allow distributed versions of SQLite, to
overcome the limitations of concurrent writes, like [**LiteFS**](https://fly.io/docs/litefs/).

I could have used any other example to learn `volume mounting` in Kubernetes, but I
decided to use SQLite because I am interested in using this database for some of my
projects.

///

## Next steps

Following a system restart, when I didn't have an internet connection, my application
stopped working because Kubernetes could not pull the Docker image
`robertoprevato/fortunecookies:latest` from Docker Hub.

My next exercise describes an interesting subject: what I did to avoid that
problem, it's about [_Loading Docker Images in Kind_](./loading-docker-images.md).
