This page describes my next exercise, of running a single
[**PostgreSQL**](https://www.postgresql.org/) database for local development. It covers:

- [X] Running PostgreSQL for development in Docker without Kubernetes.
- [X] Running PostgreSQL for development in Docker and Kubernetes, without a load balancer.
- [X] Running PostgreSQL for development in Docker and Kubernetes, with a load balancer.

This is relatively simple to set up and sufficient for local development, but has the
limitations of not supporting automatic failovers, backups, or scaling, and it is not
suitable for production. To run a PostgreSQL environment in Kubernetes that is suitable for
production or to mimic a production environment, I plan to later study how to use
one of the available [_Operators_](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/)
for PostgreSQL, such as:

- [_CloudNativePG_](https://cloudnative-pg.io/documentation/1.23/).
- [_Zalando's postgres-operator_](https://github.com/zalando/postgres-operator).

In this page I will also describe how to use `psql` and `pgAdmin` to connect to a
PostgreSQL Server.

## Running PostgreSQL in Docker without Kubernetes

This information is interesting to compare the differences of running a single
PostgreSQL server for local development, with and without Kubernetes.

To run a PostgreSQL 17 server using a volume mount to persist data in the host, run
the following commands, replacing `******` with the desired password:

```bash
# create a folder dedicated to persisting postgres
mkdir -p $HOME/stores/postgres

# start a container with PostgreSQL Server
docker run --rm \
  --name pg-docker \
  -e POSTGRES_PASSWORD=****** \
  -d \
  -p 5432:5432 \
  -v $HOME/docker/volumes/postgres:/var/lib/postgresql/data \
  postgres:17
```

Select the desired password, for `POSTGRES_PASSWORD`.

/// details | The docker command described.
    type: example

This command runs a PostgreSQL server in a Docker container named `pg-docker`:

- `--rm`: Automatically removes the container when it stops.
- `--name pg-docker`: Names the container `pg-docker`.
- `-e POSTGRES_PASSWORD=******`: Sets the desired PostgreSQL password.
- `-d`: Runs the container in detached (background) mode.
- `-p 5432:5432`: Maps port 5432 on the host to port 5432 in the container.
- `-v $HOME/docker/volumes/postgres:/var/lib/postgresql/data`: Mounts a host directory for persistent database storage.
- `postgres:17`: Uses the official PostgreSQL 17 image.

///

To verify that the PostgreSQL Server is running, you can inspect the logs of the
container with:

```bash
docker logs pg-docker
```

One of the log lines should say: _database system is ready to accept connections_.

/// details | Verify that the process is listening.

To verify the process is listening on port `5432`, run the following commands:

```bash
# Install with → sudo apt install net-tools
netstat -an | grep 5432

# or…
ss -ltnp | grep 5432
```

They should display output like:

```bash
$ netstat -an | grep 5432
tcp        0      0 0.0.0.0:5432            0.0.0.0:*               LISTEN

$ ss -ltnp | grep 5432
LISTEN 0      4096          0.0.0.0:5432       0.0.0.0:*
```

///

### Connect using psql

#### Using psql from the host

To test a connection to the PostgreSQL database using the `psql` CLI, let's install the
PostgreSQL client on the host.

To install the client, follow the official [PostgreSQL instructions](https://www.postgresql.org/download/linux/ubuntu/):

```bash
sudo apt install curl ca-certificates
sudo install -d /usr/share/postgresql-common/pgdg
sudo curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc
. /etc/os-release
sudo sh -c "echo 'deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $VERSION_CODENAME-pgdg main' > /etc/apt/sources.list.d/pgdg.list"
sudo apt update
sudo apt -y install postgresql-client-17
```

/// note | Requires extra packages.

Skip this step if you don't want to install extra packages on your `Ubuntu` host. The
following paragraph describes how to use the `psql` CLI from a Docker container.

///

Then, to connect to the PostgreSQL Server running in Docker:

```bash
PGPASSWORD=****** psql -h localhost -p 5432 -U postgres postgres
```

Here we can use **localhost** because when we started the Docker container, we used the
option `-p 5432:5432`, which maps port `5432` on the host to port `5432` in the container.
We are using **postgres** for user name and database name because these are the default
values. If we wanted to use different values when starting the container, we could use
the `POSTGRES_USER` and `POSTGRES_DB` env variables when starting the Docker container.

If the connection succeeds, you should enter the `psql` shell:

```bash
psql (17.5 (Ubuntu 17.5-1.pgdg24.04+1))
Type "help" for help.

postgres=#
```

You can run the following command in the psql shell to show the connection is working
and list all databases:

```bash
\l
```

```bash
postgres=# \l
                                                    List of databases
   Name    |  Owner   | Encoding | Locale Provider |  Collate   |   Ctype    | Locale | ICU Rules |   Access privileges
-----------+----------+----------+-----------------+------------+------------+--------+-----------+-----------------------
 postgres  | postgres | UTF8     | libc            | en_US.utf8 | en_US.utf8 |        |           |
 template0 | postgres | UTF8     | libc            | en_US.utf8 | en_US.utf8 |        |           | =c/postgres          +
           |          |          |                 |            |            |        |           | postgres=CTc/postgres
 template1 | postgres | UTF8     | libc            | en_US.utf8 | en_US.utf8 |        |           | =c/postgres          +
           |          |          |                 |            |            |        |           | postgres=CTc/postgres
(3 rows)
```

---

#### Using psql from Docker

To test a connection using `psql` within a Docker container, you can run a second
`postgres` container in interactive mode:

```bash
docker run --rm -it postgres:17 /bin/bash
```

However, in this case we cannot connect to the PostgreSQL server using `localhost`, as
`localhost` inside a Docker container does not mean `localhost` on the host.

To connect to the PostgreSQL database, find the IP address of the running container:

```bash
docker inspect pg-docker | grep IPAddress
```

In my case, it displays:

```bash {hl_lines="3-4"}
$ docker inspect pg-docker | grep IPAddress
            "SecondaryIPAddresses": null,
            "IPAddress": "172.17.0.3",
                    "IPAddress": "172.17.0.3",
```

To connect to the PostgreSQL Server, use the following command:

```bash
PGPASSWORD=****** psql -h 172.17.0.3 -p 5432 -U postgres postgres
```

```bash
root@ade51ee74b3c:/# PGPASSWORD=****** psql -h 172.17.0.3 -p 5432 -U postgres postgres
psql (17.5 (Debian 17.5-1.pgdg120+1))
Type "help" for help.

postgres=#
```

### Connect using pgAdmin

**pgAdmin** is a free and open-source administration and management tool for PostgreSQL
databases. It provides a graphical user interface (GUI) for managing PostgreSQL servers,
databases, and database objects. pgAdmin is widely used for tasks such as database
creation, schema design, data management, and user administration.

To run a container hosting a `pgAdmin` server, use the following command, replacing
`PGADMIN_DEFAULT_PASSWORD` with the desired password. The email and password are used on
`localhost` to sign-in to the pgAdmin GUI.

```bash
docker run --rm \
  -p 8080:80 \
  --name pgadmin \
  -e 'PGADMIN_DEFAULT_EMAIL=user@domain.com' \
  -e 'PGADMIN_DEFAULT_PASSWORD=******' \
  -d \
  dpage/pgadmin4
```

Then, navigate to [http://localhost:8080/](http://localhost:8080/) to access the local
instance of *pgAdmin*.

![pgAdmin sign-in](/K8sStudies/img/pgadmin-signin.png)

To sign-in, use the email and password defined in the command above
(`PGADMIN_DEFAULT_EMAIL`, `PGADMIN_DEFAULT_PASSWORD`).

Once logged in, the homepage looks like in the picture below.

![pgAdmin home](/K8sStudies/img/pgadmin-home.png)

To connect to the PostgreSQL Server:

1. Open the [`Server dialog`](https://www.pgadmin.org/docs/pgadmin4/9.4/server_dialog.html)
   clicking the right mouse button on _Servers_ in the top left corner of the page, then
   `Register > Server…`.
2. Insert the same parameters we used for the `psql` command in Docker: `postgres` for
   username and database, and the password used when starting the Docker
   container for the local environment, and the IP of the Docker container like
   described above.

![pgAdmin server dialog](/K8sStudies/img/pgadmin-server-dialog.png)

![pgAdmin connected server](/K8sStudies/img/pgadmin-connected-server.png)

### Cleaning up

Stop the Docker containers. They will be deleted, as they were created using the option
`--rm`.

```bash
docker stop pg-docker

docker stop pgadmin
```

---

## Running PostgreSQL in Docker with Kubernetes

This time, instead of deleting the last cluster created for the [_Multi Nodes example_](./multi-nodes.md),
I decided to create a new one named "db".

For now, I will not configure a load balancer to expose the PostgreSQL Server, but
use instead [**kubectl port-forward**](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/)
to connect to the service. For this reason, `kind.yaml` does not include extra port
mappings.

```bash
# ./examples/05-single-postgres
kind create cluster --name db --config kind.yaml

kubectl cluster-info --context kind-db
```

Create a secret for the PostgreSQL admin password, which is referenced by name in the
manifest, replacing `mypassword` with the desired secret:

```bash
kubectl create secret \
  generic \
  postgres-secret \
  --from-literal=POSTGRES_PASSWORD=mypassword
```

Run the deployment that provisions the *PostgreSQL Server*:

```bash
# ./examples/05-single-postgres
kubectl apply -f single-postgres.yaml
```

Wait for the pod to become ready:

```bash
kubectl wait --for=condition=ready pod -l app=postgres --timeout=120s
```

/// details | Inspecting the logs.

Inspect the logs of the container using the commands:

```bash
kubectl get pods

kubectl logs <pod-name>
```

```bash {hl_lines="3 9 20"}
$ kubectl get pods
NAME                        READY   STATUS    RESTARTS   AGE
postgres-597b764746-xgc6z   1/1     Running   0          27m

$ kubectl logs postgres-597b764746-xgc6z

PostgreSQL Database directory appears to contain a database; Skipping initialization

2025-07-28 08:27:39.831 UTC [1] LOG:  starting PostgreSQL 17.5 (Debian 17.5-1.pgdg120+1) on x86_64-pc-linux-gnu, compiled by gcc (Debian 12.2.0-14) 12.2.0, 64-bit
2025-07-28 08:27:39.831 UTC [1] LOG:  listening on IPv4 address "0.0.0.0", port 5432
2025-07-28 08:27:39.831 UTC [1] LOG:  listening on IPv6 address "::", port 5432
2025-07-28 08:27:39.834 UTC [1] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5432"
2025-07-28 08:27:39.841 UTC [34] LOG:  database system was interrupted; last known up at 2025-07-27 21:01:31 UTC
2025-07-28 08:27:40.074 UTC [34] LOG:  database system was not properly shut down; automatic recovery in progress
2025-07-28 08:27:40.077 UTC [34] LOG:  redo starts at 0/194BFE0
2025-07-28 08:27:40.077 UTC [34] LOG:  invalid record length at 0/194C100: expected at least 24, got 0
2025-07-28 08:27:40.077 UTC [34] LOG:  redo done at 0/194C0C8 system usage: CPU: user: 0.00 s, system: 0.00 s, elapsed: 0.00 s
2025-07-28 08:27:40.087 UTC [32] LOG:  checkpoint starting: end-of-recovery immediate wait
2025-07-28 08:27:40.098 UTC [32] LOG:  checkpoint complete: wrote 3 buffers (0.0%); 0 WAL file(s) added, 0 removed, 0 recycled; write=0.004 s, sync=0.002 s, total=0.015 s; sync files=2, longest=0.001 s, average=0.001 s; distance=0 kB, estimate=0 kB; lsn=0/194C100, redo lsn=0/194C100
2025-07-28 08:27:40.103 UTC [1] LOG:  database system is ready to accept connections
```

///

To connect to the PostgreSQL Server, we can use `kubectl port-forward` to create a
tunnel to the service defined in the manifest.

```bash
kubectl port-forward svc/postgres 5432:5432
```

```bash
$ PGPASSWORD=****** psql -h localhost -p 5432 -U myuser mydb
psql (17.5 (Ubuntu 17.5-1.pgdg24.04+1))
Type "help" for help.

mydb=#
```

/// admonition | Issues with extra port mappings.
    type: danger

I also tried configuring `extraPortMappings` in the `Kind` node to connect to the
PostgreSQL server, but that doesn't work.

According to GitHub Copilot:

> You cannot connect to PostgreSQL using the NodePort address with Kind's extraPortMappings because Kind does not natively support forwarding traffic from the host to service NodePorts inside the cluster without a proper load balancer or additional networking setup.

> This is a known limitation: mapping a host port to a container port in Kind only exposes the port on the control-plane node's container, not directly to the Kubernetes service's NodePort. The NodePort is accessible from within the Kind network, but not from your host machine unless you use a load balancer or kubectl port-forward.

///

### Using a Load Balancer

Later I wanted to deploy a PostgreSQL Server again, but this time making it accessible
using a _Load Balancer_ instead of using `port-forward`. To implement the _Load Balancer_
in Kind, I initially tried using _MetalLB_, which is a popular tool when working with Kubernetes
outside of cloud environments. According to _MetalLB_'s documentation, load balancers
for bare-metal clusters (without using cloud vendors) in Kubernetes are not
"first class citizens". However, I had issues making _MetalLB_ work with Kind, and I
finally decided to try using the _Load Balancer_ [features offered by Kind](https://kind.sigs.k8s.io/docs/user/loadbalancer).

/// note | Installing Cloud Provider Kind.

To install `Cloud Provider Kind`, follow [the documentation](https://github.com/kubernetes-sigs/cloud-provider-kind?tab=readme-ov-file#install).
One way is to download one of the [released binaries](https://github.com/kubernetes-sigs/cloud-provider-kind/releases).

```bash
wget https://github.com/kubernetes-sigs/cloud-provider-kind/releases/download/v0.7.0/cloud-provider-kind_0.7.0_linux_amd64.tar.gz

tar -xzf cloud-provider-kind_0.7.0_linux_amd64.tar.gz

sudo mv cloud-provider-kind /usr/local/bin/
```

///

Start `cloud-provider-kind` in a different terminal:

```bash
cloud-provider-kind
```

/// admonition | MetalLB and Kind.
    type: warning

I tried using MetalLB with Kind, also following relatively recent tutorials,
but all my attempts failed because of parts that were not working. I finally
gave up and decided to use the _Load Balancer_ [features offered by Kind](https://kind.sigs.k8s.io/docs/user/loadbalancer).
I will try using MetalLB again with real nodes, when using `Kubeadm` to setup a
real Kubernetes cluster.

///

Delete the `db` cluster, and recreate it using the `kind.yaml` file.

```bash
# ./examples/05-single-postgres
kind delete cluster --name db

kind create cluster --name db --config kind.yaml

# create postgres
kubectl create secret \
  generic \
  postgres-secret \
  --from-literal=POSTGRES_PASSWORD=mypassword

kubectl apply -f single-postgres-lb.yaml
```

Wait for the PostgreSQL Service to become available:

```bash
kubectl wait --for=condition=ready pod -l app=postgres --timeout=120s
```

Obtain the IP address of the load balancer:

```bash
LB_IP=$(kubectl get svc/postgres -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
```

Try connecting using `psql`:

```bash
PGPASSWORD=mypassword psql -h $LB_IP -p 5432 -U myuser mydb
```

## Next steps

In my next exercise, I will practice with [_PostgreSQL Operators_](./postgresql-operators.md).
